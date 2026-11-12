import SwiftUI

/// The prototype's map analyses (`ANALYSES`): a per-home metric that colors
/// the pins, drives the legend card and can sort the results. Keys match
/// `SearchAnalysis.key` ("parks", "ppsf", "transit", "to:6", ...).
nonisolated struct HomeAnalysis: Sendable {
    let key: String
    /// Legend title, e.g. "Distance to nearest park".
    let title: String
    /// Pill label, e.g. "Distance to parks".
    let pill: String
    /// Sort chip label, e.g. "Closest to a park".
    let sortTitle: String
    let lowCaption: String
    let highCaption: String
    /// Lower is better. nil means the home has no value (gray pin).
    let value: @Sendable (Listing) -> Double?
    let label: @Sendable (Listing) -> String
    let format: @Sendable (Double) -> String
}

nonisolated enum HomeAnalyses {
    typealias Place = (name: String, lat: Double, lng: Double)

    static let parks: [Place] = [
        ("Woodland Park", 47.6685, -122.3478), ("Green Lake Park", 47.6799, -122.3291), ("Gas Works Park", 47.6456, -122.3344),
        ("Golden Gardens Park", 47.6907, -122.4030), ("Ravenna Park", 47.6716, -122.3076), ("Discovery Park", 47.6573, -122.4057),
        ("Fremont Peak Park", 47.6553, -122.3532), ("Salmon Bay Park", 47.6795, -122.3832), ("Ballard Commons Park", 47.6683, -122.3843),
        ("Wallingford Playfield", 47.6596, -122.3378),
    ]
    static let grocery: [Place] = [
        ("PCC Fremont", 47.6510, -122.3505), ("Fred Meyer Ballard", 47.6684, -122.3770), ("QFC Wallingford", 47.6614, -122.3343),
        ("Whole Foods Roosevelt", 47.6764, -122.3170), ("Safeway Greenwood", 47.6930, -122.3554), ("Trader Joe’s Ballard", 47.6690, -122.3858),
        ("PCC Green Lake", 47.6807, -122.3260), ("Ballard Market", 47.6779, -122.3870),
    ]
    static let schools: [Place] = [
        ("Whittier Elementary", 47.6857, -122.3726), ("Greenwood Elementary", 47.6905, -122.3550), ("B.F. Day Elementary", 47.6508, -122.3497),
        ("Green Lake Elementary", 47.6795, -122.3360), ("Hamilton Middle School", 47.6566, -122.3356), ("Ballard High School", 47.6779, -122.3759),
    ]
    static let landmarks: [Place] = [
        ("Green Lake", 47.6800, -122.3290), ("Woodland Park Zoo", 47.6685, -122.3504), ("Gas Works Park", 47.6456, -122.3344),
        ("the Fremont Troll", 47.6510, -122.3473), ("the University of Washington", 47.6553, -122.3035), ("the Ballard Locks", 47.6655, -122.3972),
        ("South Lake Union", 47.6256, -122.3365), ("the Space Needle", 47.6205, -122.3493), ("Golden Gardens", 47.6907, -122.4030),
    ]

    static func nearest(_ l: Listing, _ places: [Place]) -> (name: String, miles: Double) {
        places.map { (name: $0.name, miles: TravelTime.miles(l.latitude, l.longitude, $0.lat, $0.lng)) }
            .min { $0.miles < $1.miles } ?? ("", 0)
    }

    private static func distance(_ key: String, title: String, pill: String, sort: String, _ places: [Place], strip: String = "^the ") -> HomeAnalysis {
        HomeAnalysis(key: key, title: title, pill: pill, sortTitle: sort, lowCaption: "Closer", highCaption: "Farther",
                     value: { nearest($0, places).miles },
                     label: { l in
                         let n = nearest(l, places)
                         return String(format: "%.1f mi to ", n.miles) + n.name.replacingOccurrences(of: strip, with: "", options: .regularExpression)
                     },
                     format: { String(format: "%.1f mi", $0) })
    }

    static let all: [String: HomeAnalysis] = {
        var out: [String: HomeAnalysis] = [
            "parks": distance("parks", title: "Distance to nearest park", pill: "Distance to parks", sort: "Closest to a park", parks, strip: " Park$"),
            "ppsf": HomeAnalysis(key: "ppsf", title: "Price per sq ft", pill: "Price per sq ft", sortTitle: "Price per sq ft: low to high",
                                 lowCaption: "Lower", highCaption: "Higher",
                                 value: { $0.sqft > 0 ? Double($0.price) / Double($0.sqft) : nil },
                                 label: { $0.sqft > 0 ? "$\(Int((Double($0.price) / Double($0.sqft)).rounded())) / sq ft" : "No sq ft listed" },
                                 format: { "$\(Int($0.rounded()))" }),
            "transit": HomeAnalysis(key: "transit", title: "Transit score", pill: "Transit score", sortTitle: "Transit score: high to low",
                                    lowCaption: "Higher", highCaption: "Lower",
                                    value: { $0.facts?.transitScore.map { -Double($0) } },
                                    label: { $0.facts?.transitScore.map { "Transit score \($0)" } ?? "No transit score" },
                                    format: { String(Int(-$0)) }),
            "grocery": distance("grocery", title: "Distance to a grocery store", pill: "Distance to groceries", sort: "Closest to a grocery store", grocery),
            "groceryN": HomeAnalysis(key: "groceryN", title: "Grocery stores within 1 mi", pill: "Grocery stores nearby", sortTitle: "Most grocery stores nearby",
                                     lowCaption: "More", highCaption: "Fewer",
                                     value: { l in -Double(grocery.filter { TravelTime.miles(l.latitude, l.longitude, $0.lat, $0.lng) <= 1 }.count) },
                                     label: { l in
                                         let n = grocery.filter { TravelTime.miles(l.latitude, l.longitude, $0.lat, $0.lng) <= 1 }.count
                                         return "\(n) grocery store\(n == 1 ? "" : "s") within 1 mi"
                                     },
                                     format: { String(Int(-$0)) }),
            "schools": distance("schools", title: "Distance to a school", pill: "Distance to schools", sort: "Closest to a school", schools),
        ]
        for (i, l) in landmarks.enumerated() {
            let name = l.name.replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
            out["to:\(i)"] = distance("to:\(i)", title: "Distance to \(l.name)", pill: "Distance to \(name)", sort: "Closest to \(name)", [l])
        }
        return out
    }()

    /// Patterns that name each landmark in a request ("slu", "the zoo").
    static let landmarkPatterns = [#"green ?lake"#, #"\bzoo\b|woodland park"#, #"gas ?works"#, #"\btroll\b"#,
                                   #"\b(uw|u ?dub|university of washington)\b"#, #"\blocks\b"#, #"south lake union|\bslu\b|amazon"#,
                                   #"space needle|seattle center"#, #"golden gardens"#]

    /// Travel-time targets (the prototype's `TT`): landmarks, then parks not already covered.
    static let travelTargets: [(place: Place, pattern: String)] = {
        var out = zip(landmarks, landmarkPatterns).map { (place: $0.0, pattern: $0.1) }
        for p in parks where !landmarkPatterns.contains(where: { p.name.lowercased().rx($0) }) {
            let core = p.name.lowercased().replacingOccurrences(of: " park", with: "")
            out.append((p, #"\b"# + NSRegularExpression.escapedPattern(for: core) + #"\b"#))
        }
        return out
    }()

    enum TravelMode: String, Sendable, CaseIterable {
        case drive, transit, walk, bike
        var noun: String { rawValue }
        /// Detour factor, average mph and fixed minutes (parking, waiting).
        var params: (f: Double, mph: Double, base: Double, note: String) {
            switch self {
            case .drive: (1.4, 24, 3, " without traffic")
            case .transit: (1.35, 11, 8, ", including the wait")
            case .walk: (1.25, 3, 0, "")
            case .bike: (1.3, 10, 1, "")
            }
        }
    }

    /// Minutes from a home to a target by mode (the prototype's `ttMin`).
    static func travelMinutes(_ l: Listing, _ target: Place, _ mode: TravelMode) -> Int {
        let m = mode.params
        let miles = TravelTime.miles(l.latitude, l.longitude, target.lat, target.lng)
        return max(1, Int((miles * m.f / m.mph * 60 + m.base).rounded()))
    }

    /// Built-in analyses plus travel-time ones keyed "tt:<target>:<mode>".
    static func lookup(_ key: String) -> HomeAnalysis? {
        if let a = all[key] { return a }
        let parts = key.split(separator: ":")
        guard parts.count == 3, parts[0] == "tt", let i = Int(parts[1]), travelTargets.indices.contains(i),
              let mode = TravelMode(rawValue: String(parts[2])) else { return nil }
        let t = travelTargets[i].place
        let name = t.name.replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
        let noun = mode.noun.capitalizedFirst
        return HomeAnalysis(key: key, title: "\(noun) time to \(t.name)", pill: "\(noun) time to \(name)",
                            sortTitle: "Shortest \(mode.noun) to \(name)", lowCaption: "Shorter", highCaption: "Longer",
                            value: { Double(travelMinutes($0, t, mode)) },
                            label: { "\(travelMinutes($0, t, mode)) min \(mode.noun) to \(name)" },
                            format: { "\(Int($0.rounded())) min" })
    }

    // MARK: Color ramp

    private static let ramp: [(Double, Double, Double)] = [(42, 57, 111), (158, 63, 113), (253, 188, 150)]

    /// Pin fill and text color for a 0–1 position on the ramp (0 = best).
    @MainActor static func rampColors(_ t: Double) -> (fill: Color, text: Color) {
        let t = min(max(t, 0), 1)
        let (a, b, u) = t < 0.5 ? (ramp[0], ramp[1], t * 2) : (ramp[1], ramp[2], (t - 0.5) * 2)
        let c = (a.0 + (b.0 - a.0) * u, a.1 + (b.1 - a.1) * u, a.2 + (b.2 - a.2) * u)
        let luminance = (0.2126 * c.0 + 0.7152 * c.1 + 0.0722 * c.2) / 255
        return (Color(red: c.0 / 255, green: c.1 / 255, blue: c.2 / 255), luminance > 0.5 ? Nova.Color.gray800 : .white)
    }

    @MainActor static let rampGradient = LinearGradient(
        colors: ramp.map { Color(red: $0.0 / 255, green: $0.1 / 255, blue: $0.2 / 255) },
        startPoint: .leading, endPoint: .trailing
    )
}
