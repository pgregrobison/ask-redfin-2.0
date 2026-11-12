import Foundation

/// The iOS Vision prototype's listing set: 335 Seattle homes from
/// `Resources/Data/listings.json`, plus the details the data doesn't carry
/// (transit score, condition, criteria matches, features, basement, garage).
/// Those are derived from the same FNV-1a hashes the prototype uses, so every
/// home answers the same way here as it does in the Claude Design prototype.
nonisolated final class HomeCatalog: Sendable {
    static let shared = HomeCatalog()

    /// The five criteria the intro query asks for. Each one is "known" for a
    /// fixed 55% of homes; any other criterion is a coin flip per home.
    static let knownCriteria = ["natural light", "finished basement", "large yard", "home office", "quiet street"]
    static let homeTypes = ["House", "Townhouse", "Condo", "Multi-family"]
    static let features = ["Garage", "Air conditioning", "Fireplace", "Washer/dryer", "Waterfront", "Pool", "Primary bed on main", "Exclude short sales"]
    static let conditions = ["Excellent", "Good", "Good", "Good", "Fair", "Needs work"]
    static let exteriorPhotos = [
        "ext-brick-bungalow", "ext-brick-stone", "ext-craftsman-flowers", "ext-craftsman-mountain",
        "ext-craftsman-swing", "ext-farmhouse", "ext-grey-cottage", "ext-modern-duplex", "ext-modern-white",
        "ext-shingle-hydrangea", "ext-shingle-red-door", "ext-split-level", "ext-stucco-ranch", "ext-townhouse-row"
    ]

    let listings: [Listing]
    private let byID: [String: Listing]

    private init() {
        let rows = Self.loadRows()
        listings = rows.enumerated().map { Self.makeListing(row: $0.element, number: $0.offset + 1) }
        byID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
    }

    func listing(id: String) -> Listing? { byID[id] }

    // MARK: - Attribute lookups (mirror the prototype's `has` / `hasFeat`)

    /// Whether a home matches a free-text criterion ("natural light", "rooftop deck").
    static func has(_ listing: Listing, _ criterion: String) -> Bool {
        let c = criterion.lowercased()
        if knownCriteria.contains(c) {
            return listing.facts?.criteria.contains(c) ?? false
        }
        return hash(listing.hashKey + "|" + c) % 10 < 5
    }

    /// Whether a home has one of the structured feature filters.
    static func hasFeature(_ listing: Listing, _ feature: String) -> Bool {
        switch feature {
        case "Primary bed on main": return listing.facts?.primaryBedOnMain ?? false
        case "Exclude short sales": return !(listing.facts?.isShortSale ?? false)
        default:
            let cutoff: UInt32 = (feature == "Waterfront" || feature == "Pool") ? 2 : 6
            return hash(listing.hashKey + "#" + feature) % 10 < cutoff
        }
    }

    /// Monthly HOA, filling in a plausible figure for non-houses that don't list one.
    static func hoa(_ listing: Listing) -> Int {
        if let hoa = listing.facts?.hoaMonthly { return hoa }
        return listing.propertyType == "House" ? 0 : 150 + Int(hash(listing.hashKey + "hoa") % 350)
    }

    // MARK: - Hash

    /// 32-bit FNV-1a over UTF-16 code units, identical to the prototype's `hash`.
    static func hash(_ s: String) -> UInt32 {
        var h: UInt32 = 2166136261
        for unit in s.utf16 {
            h ^= UInt32(unit)
            h = h &* 16777619
        }
        return h
    }

    // MARK: - Loading

    private struct Row {
        let address: String
        let city: String
        let zip: String
        let price: Int
        let beds: Int
        let baths: Double
        let sqft: Int
        let type: String
        let hood: String
        let year: Int?
        let dom: Int?
        let hoa: Int?
        let lot: Int?
        let lat: Double
        let lng: Double
        let url: String?
        let status: String
        let open: String
    }

    private static func loadRows() -> [Row] {
        guard let url = Bundle.main.url(forResource: "listings", withExtension: "json")
                ?? Bundle.main.url(forResource: "listings", withExtension: "json", subdirectory: "Resources/Data"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cols = json["cols"] as? [String],
              let rows = json["rows"] as? [[Any]]
        else { return [] }

        func index(_ key: String) -> Int? { cols.firstIndex(of: key) }
        return rows.map { r in
            func value(_ key: String) -> Any? {
                guard let i = index(key), i < r.count, !(r[i] is NSNull) else { return nil }
                return r[i]
            }
            func int(_ key: String) -> Int? { (value(key) as? NSNumber)?.intValue }
            func double(_ key: String) -> Double? { (value(key) as? NSNumber)?.doubleValue }
            func string(_ key: String) -> String? { value(key) as? String }
            return Row(
                address: string("address") ?? "",
                city: string("city") ?? "Seattle",
                zip: string("zip") ?? "",
                price: int("price") ?? 0,
                beds: int("beds") ?? 0,
                baths: double("baths") ?? 0,
                sqft: int("sqft") ?? 0,
                type: string("type") ?? "House",
                hood: string("hood") ?? "",
                year: int("year"),
                dom: int("dom"),
                hoa: int("hoa"),
                lot: int("lot"),
                lat: double("lat") ?? 0,
                lng: double("lng") ?? 0,
                url: string("url"),
                status: string("status") ?? "Active",
                open: string("open") ?? ""
            )
        }
    }

    private static func makeListing(row: Row, number: Int) -> Listing {
        let id = String(number)
        let h = { (key: String) in hash(id + key) }
        let addressHash = hash(row.address)
        let isCondo = row.type == "Condo"

        let transit = h("tr")
        let criteria = Set(knownCriteria.filter { c in
            if isCondo && (c == "finished basement" || c == "large yard") { return false }
            return hash(id + "|" + c) % 100 < 55
        })
        let year = row.year.flatMap { $0 > 0 ? $0 : nil } ?? 1905 + Int(h("yr") % 115)
        let dom = row.dom ?? 1 + Int(h("dom") % 45)

        // Basement and garage sizes, kept consistent with the yes/no criteria
        // and features so answers never contradict each other.
        let sq = row.sqft
        var basement = 0
        var basementFinished = false
        if !isCondo && sq > 0 {
            if criteria.contains("finished basement") {
                basement = roundTo10(Double(sq) * (0.2 + Double(hash(id + "|bs") % 26) / 100))
                basementFinished = true
            } else if (row.type == "House" || row.type == "Multi-family") && hash(id + "|ub") % 100 < 30 {
                basement = roundTo10(Double(sq) * (0.22 + Double(hash(id + "|bs") % 22) / 100))
            }
        }
        let hasGarage = hash(id + "#Garage") % 10 < 6
        var garage = 0
        if hasGarage {
            garage = isCondo ? 1 : 1 + (hash(id + "|g2") % 100 < 38 ? 1 : 0) + (sq > 3800 && hash(id + "|g3") % 100 < 40 ? 1 : 0)
        }

        let facts = HomeFacts(
            number: number,
            transitScore: transit % 12 == 0 ? nil : 38 + Int(transit % 60),
            condition: conditions[Int(h("cd") % 6)],
            isShortSale: h("ss") % 22 == 0,
            primaryBedOnMain: !isCondo && h("mb") % 3 == 0,
            criteria: criteria,
            basementSqft: basement,
            basementFinished: basementFinished,
            garageCars: garage,
            lotSqft: !isCondo && (row.lot ?? 0) > 500 ? row.lot : nil,
            hoaMonthly: row.hoa,
            openHouse: row.open.isEmpty ? nil : row.open,
            redfinURL: row.url,
            status: row.status,
            photoName: exteriorPhotos[Int(addressHash % UInt32(exteriorPhotos.count))]
        )

        let hoaText: String = {
            let monthly = row.hoa ?? (row.type == "House" ? 0 : 150 + Int(h("hoa") % 350))
            return monthly > 0 ? "$\(monthly)/mo" : "N/A"
        }()
        let lotText = facts.lotSqft.map { "\($0.formatted()) sqft" } ?? "N/A"
        var tags: [String] = []
        if facts.openHouse != nil { tags.append("Open house") }
        if hoaText == "N/A" { tags.append("No HOA") }
        if facts.isShortSale { tags.append("Short sale") }

        return Listing(
            id: id,
            price: row.price,
            address: row.address,
            city: row.city,
            neighborhood: row.hood.isEmpty ? nil : row.hood,
            state: "WA",
            zip: row.zip,
            beds: row.beds,
            baths: row.baths,
            sqft: row.sqft,
            latitude: row.lat,
            longitude: row.lng,
            photos: [HomePhotos.url(facts.photoName)] + HousePhotos.interiorURLs,
            description: describe(row: row, year: year),
            yearBuilt: year,
            lotSize: lotText,
            propertyType: row.type,
            // `dom <= 3` treats a missing value as 0, like the prototype.
            isHotHome: (row.dom ?? 0) <= 3 && addressHash % 3 == 0,
            tags: tags,
            daysOnMarket: dom,
            hoaDues: hoaText,
            buyerAgentFee: "2.5%",
            facts: facts
        )
    }

    private static func roundTo10(_ v: Double) -> Int { Int((v / 10).rounded()) * 10 }

    private static func describe(row: Row, year: Int) -> String {
        let type = row.type == "Multi-family" ? "multi-family home" : row.type.lowercased()
        let place = row.hood.isEmpty || row.hood == "Seattle" ? "Seattle" : row.hood
        let size = row.sqft > 0 ? " with \(row.sqft.formatted()) sq ft" : ""
        return "\(row.beds)-bedroom \(type) in \(place)\(size), built in \(year)."
    }
}

/// Per-home details derived from the prototype's hashes.
nonisolated struct HomeFacts: Codable, Hashable, Sendable {
    /// The prototype's numeric id (1-based row in `listings.json`).
    let number: Int
    let transitScore: Int?
    let condition: String
    let isShortSale: Bool
    let primaryBedOnMain: Bool
    /// Which of `HomeCatalog.knownCriteria` this home matches.
    let criteria: Set<String>
    let basementSqft: Int
    let basementFinished: Bool
    let garageCars: Int
    let lotSqft: Int?
    let hoaMonthly: Int?
    let openHouse: String?
    let redfinURL: String?
    let status: String
    let photoName: String
}

extension Listing {
    /// Key the prototype hashes per-home attributes on: its numeric id for
    /// catalog homes, the string id for anything else (demo fixtures).
    nonisolated var hashKey: String { facts.map { String($0.number) } ?? id }
}

/// Bundled exterior photos from the prototype (`Resources/HomePhotos`).
nonisolated enum HomePhotos {
    static func url(_ name: String) -> String {
        let url = Bundle.main.url(forResource: name, withExtension: "jpg")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Resources/HomePhotos")
        return url?.absoluteString ?? ""
    }
}
