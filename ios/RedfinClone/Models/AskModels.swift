import Foundation

/// A button under a reply that hands off to a flow (Phase 6 draws the sheets).
nonisolated struct AskCTA: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case tour, rocket, agent, myHome }
    var label: String
    var kind: Kind
    var listingID: String? = nil
    var price: Int? = nil
}

/// A watch on a home: "tell me if the price drops under $1.2M".
nonisolated struct HomeWatch: Codable, Hashable, Sendable, Identifiable {
    enum Condition: String, Codable, Sendable { case price, pending, openHouse, anyDrop }
    enum Action: String, Codable, Sendable { case tell, tour }
    enum Status: String, Codable, Sendable { case on, hit, off }

    var id: String
    var listingID: String
    var condition: Condition
    /// Price limit for `.price`.
    var value: Int = 0
    var label: String
    /// "the price drops under $1.2M"
    var phrase: String
    var action: Action
    var status: Status = .on
}

/// The tour-day picker: candidate homes with the ones to visit checked.
nonisolated struct TourPick: Equatable, Sendable {
    var day: String            // "Sat" / "Sun"
    var start: Int             // minutes after midnight
    var candidates: [String]
    var selected: Set<String>
    var done = false
}

/// A planned tour day: stops in route order with arrival times.
nonisolated struct TourPlan: Equatable, Sendable {
    struct Stop: Equatable, Sendable { var listingID: String; var at: Int; var drive: Int }
    var day: String
    var start: Int
    var stops: [Stop]
    var end: Int
    var driveTotal: Int
    var requested = false
}

/// Inline content under a reply (Phase 5 renders these).
nonisolated enum AskWidget: Equatable, Sendable {
    case homes([String], total: Int)
    case compare([String])
    case pick(TourPick)
    case itinerary(TourPlan)
    case debrief([String])
    case watch([HomeWatch])
    case inspiration
    case addPhoto
    /// "Set minimum to 2,300 sq ft" / "Keep as is"
    case confirmMinSqft(Int, yes: String, no: String)
}
