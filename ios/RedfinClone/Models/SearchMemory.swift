import Foundation

/// One line of an Ask Redfin conversation as the prototype stores it:
/// what you typed, a tool confirmation ("Added “home office”"), or a reply.
nonisolated struct AskLogEntry: Codable, Hashable, Sendable {
    enum From: String, Codable, Sendable { case user, tool, bot }
    var from: From
    var text: String
}

/// Everything needed to pick a chat back up: the search, saved homes and the log.
nonisolated struct SearchMemory: Codable, Hashable, Sendable {
    var search: SearchState
    var favorites: [String]
    var log: [AskLogEntry]
    var timestamp: Date
    var title: String? = nil
}

/// A past chat in the Chats menu.
nonisolated struct SearchThread: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var title: String
    var timestamp: Date
    var memory: SearchMemory
}

/// Persists the current session and up to 8 past chats (the prototype's
/// `redfin-ios-vision:memory` / `:threads`), seeding 3 demo chats so
/// "pick up where I left off" works on a first launch.
@MainActor
final class SearchMemoryStore {
    static let maxThreads = 8
    private let defaults: UserDefaults
    private let memoryKey = "askRedfin.vision.memory"
    private let threadsKey = "askRedfin.vision.threads"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Current session

    func loadCurrent() -> SearchMemory? { decode(SearchMemory.self, memoryKey) }

    func saveCurrent(_ memory: SearchMemory) { encode(memory, memoryKey) }

    func clearCurrent() { defaults.removeObject(forKey: memoryKey) }

    // MARK: Threads

    func loadThreads() -> [SearchThread] { decode([SearchThread].self, threadsKey) ?? [] }

    func saveThreads(_ threads: [SearchThread]) {
        encode(Array(threads.sorted { $0.timestamp > $1.timestamp }.prefix(Self.maxThreads)), threadsKey)
    }

    /// Adds a chat to the list (newest first), replacing one with the same id
    /// or the same log. Chats you never typed in aren't kept.
    func archive(_ memory: SearchMemory, id: String? = nil) {
        guard let first = memory.log.first(where: { $0.from == .user })?.text else { return }
        let threadID = id ?? "t\(Int(memory.timestamp.timeIntervalSince1970 * 1000))"
        var threads = loadThreads().filter { $0.id != threadID && $0.memory.log != memory.log }
        let title = memory.title ?? (first.count > 60 ? String(first.prefix(59)) + "…" : first)
        threads.insert(SearchThread(id: threadID, title: title, timestamp: memory.timestamp, memory: memory), at: 0)
        saveThreads(threads)
    }

    func removeThread(id: String) {
        saveThreads(loadThreads().filter { $0.id != id })
    }

    /// Re-seeds the demo chats on every launch so their counts track the data.
    func seedDemoThreads(listings: [Listing]) {
        saveThreads(loadThreads().filter { !$0.id.hasPrefix("demo") })
        for (i, memory) in Self.demoMemories(listings: listings).enumerated() {
            archive(memory, id: "demo\(i + 1)")
        }
    }

    // MARK: Demo chats (the prototype's `demoThreads`)

    static func demoMemories(listings: [Listing], now: Date = .now) -> [SearchMemory] {
        func daysAgo(_ n: Double) -> Date { now.addingTimeInterval(-n * 86_400 - 3_600 * (2 + n)) }
        func homes(_ n: Int) -> String { n == 1 ? "1 home" : "\(n) homes" }
        func pool(_ s: SearchState) -> [Listing] {
            SearchRegions.shared.pool(listings, locations: s.locations).filter { SearchEngine.passes($0, s.filters) }
        }
        func tool(_ t: String) -> AskLogEntry { AskLogEntry(from: .tool, text: t) }
        func user(_ t: String) -> AskLogEntry { AskLogEntry(from: .user, text: t) }
        func bot(_ t: String) -> AskLogEntry { AskLogEntry(from: .bot, text: t) }

        // 1. Ballard and Fremont, with a must-have and a tour.
        var s1 = SearchState()
        s1.locations = ["Ballard", "Fremont"]
        s1.filters.maxPrice = 1_200_000
        s1.filters.beds = 3
        s1.criteria = ["natural light", "large yard", "home office"]
        s1.modes = ["home office": .must]
        s1.exposed = ["price", "rooms"]
        s1.savedSearch = true
        let p1 = pool(s1)
        let a = p1.first, b = p1.dropFirst().first ?? p1.first
        if let b { s1.tours = [ScheduledTour(listingID: b.id, day: "Sat", time: "11:00 AM")] }
        var log1 = [
            user("3 beds in Ballard or Fremont under $1.2M with natural light and a large yard"),
            tool("Set price to up to $1.2M and 3+ beds"),
            bot("Showing \(homes(p1.count)) in Ballard and Fremont, ranked by your 2 criteria."),
            user("A home office is a must-have"),
            tool("Added “home office” as a must-have"),
            bot("Showing only the homes that mention a home office. Homes without it are hidden."),
        ]
        if let b {
            log1 += [
                user("Schedule a tour of \(b.address)"),
                tool("Requested a tour of \(b.address)"),
                bot("You’re set to tour \(b.address) Saturday at 11:00 AM. A Redfin agent will confirm by text."),
            ]
        }
        let m1 = SearchMemory(search: s1, favorites: a.map { [$0.id] } ?? [], log: log1, timestamp: daysAgo(1),
                              title: "Ballard and Fremont, 3 beds under $1.2M")

        // 2. Car-free townhomes in 98103.
        var s2 = SearchState()
        s2.locations = ["98103"]
        s2.filters.maxPrice = 1_300_000
        s2.filters.types = ["Townhouse"]
        s2.criteria = ["rooftop deck", "walkable"]
        let p2 = pool(s2)
        let transit = p2.filter { $0.facts?.transitScore != nil }
            .max { ($0.facts?.transitScore ?? 0) < ($1.facts?.transitScore ?? 0) }
        let log2 = [
            user("Townhomes in 98103 under $1.3M"),
            tool("Moved your search to 98103"),
            tool("Set home type to townhouse and price to up to $1.3M"),
            bot("Showing \(homes(p2.count)) in 98103."),
            user("I don’t have a car, which ones are easiest to get around from?"),
            bot(transit.map { "\($0.address) has the highest transit score, \($0.facts?.transitScore ?? 0). Want me to sort by transit score?" }
                ?? "None of these list a transit score yet."),
            user("Add a rooftop deck and walkable"),
            tool("Added “rooftop deck” and “walkable”"),
            bot("Showing \(homes(p2.count)), ranked by your 2 criteria."),
            user("Is the cheapest one a good deal?"),
            bot("I can’t say whether a home is a good deal. A Redfin agent can pull recent nearby sales so you can compare. I can also color pins by price per sq ft."),
        ]
        let m2 = SearchMemory(search: s2, favorites: transit.map { [$0.id] } ?? [], log: log2, timestamp: daysAgo(3),
                              title: "Car-free townhomes in 98103")

        // 3. Queen Anne with a dealbreaker and a saved search.
        var s3 = SearchState()
        s3.locations = ["Queen Anne"]
        s3.filters.minPrice = 1_000_000
        s3.filters.beds = 4
        s3.criteria = ["view", "finished basement", "busy street"]
        s3.modes = ["busy street": .deal]
        s3.exposed = ["price", "rooms"]
        s3.savedSearch = true
        let p3 = pool(s3)
        var log3 = [
            user("4 bedroom houses in Queen Anne over $1M with a view and a finished basement"),
            tool("Moved your search to Queen Anne"),
            tool("Set price to $1M+ and 4+ beds"),
            bot("Showing \(homes(p3.count)) in Queen Anne, ranked by your 2 criteria."),
            user("Busy streets are a dealbreaker"),
            tool("Added “busy street” as a dealbreaker"),
            bot("Hiding homes that mention a busy street."),
        ]
        if let top = p3.first {
            // Drive time to South Lake Union (47.6256, -122.3365), the prototype's `ttMin(..., 'drive')`.
            let miles = TravelTime.miles(top.latitude, top.longitude, 47.6256, -122.3365)
            let minutes = max(1, Int((miles * 1.4 / 24 * 60 + 3).rounded()))
            log3 += [
                user("How long is the drive to South Lake Union from \(top.address)?"),
                bot("About \(minutes) minutes from \(top.address) without traffic."),
            ]
        }
        log3 += [user("Save my search"), tool("Saved search"), bot("Saved. I’ll let you know when new homes match.")]
        let m3 = SearchMemory(search: s3, favorites: p3.prefix(2).map(\.id), log: log3, timestamp: daysAgo(6),
                              title: "Queen Anne family homes with a view")

        return [m1, m2, m3]
    }

    // MARK: Coding

    private func decode<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

nonisolated enum TravelTime {
    /// Great-circle miles, like the prototype's `miles`.
    static func miles(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = Double.pi / 180
        let dLat = (lat2 - lat1) * r, dLng = (lng2 - lng1) * r
        let h = pow(sin(dLat / 2), 2) + cos(lat1 * r) * cos(lat2 * r) * pow(sin(dLng / 2), 2)
        return 7917.6 * asin(sqrt(h))
    }
}
