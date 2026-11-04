import Foundation

// The iOS Vision prototype's search model: where you're looking, structured
// filters, free-text criteria (nice-to-have / must-have / dealbreaker, each
// toggleable), refinements, analysis and sort. Everything here is a value
// type so a snapshot for undo is just a copy.

/// How a criterion affects results. Nice-to-haves rank; must-haves and
/// dealbreakers filter.
nonisolated enum CriterionMode: String, Codable, Hashable, Sendable {
    case nice, must, deal
}

/// Structured filters (the prototype's `F0`). Zero means "any".
nonisolated struct HomeFilters: Codable, Hashable, Sendable {
    var status = "sale"
    var minPrice = 0
    var maxPrice = 0
    var beds = 0
    var baths: Double = 0
    var types: [String] = []
    var minSqft = 0
    var maxSqft = 0
    /// Max monthly HOA; -1 means "no HOA".
    var hoa = 0
    /// Max days on Redfin.
    var daysOnMarket = 0
    var features: [String] = []
    /// Not in the prototype; kept for the existing "Hot homes" filter.
    var hotOnly = false

    var isEmpty: Bool { self == HomeFilters() }

    /// Filter count for the Filters pill badge (criteria are counted separately).
    var activeCount: Int {
        (minPrice > 0 || maxPrice > 0 ? 1 : 0) + (beds > 0 ? 1 : 0) + (baths > 0 ? 1 : 0) + (types.isEmpty ? 0 : 1)
            + (minSqft > 0 || maxSqft > 0 ? 1 : 0) + (hoa != 0 ? 1 : 0) + (daysOnMarket > 0 ? 1 : 0) + features.count + (hotOnly ? 1 : 0)
    }
}

/// A set of homes the chat narrowed to ("within a 20 min drive of SLU").
nonisolated struct SearchRefinement: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var label: String
    var listingIDs: [String]
    var isOn = true
}

/// Pins colored by a metric ("Distance to parks"). Keys match the prototype's `ANALYSES`.
nonisolated struct SearchAnalysis: Codable, Hashable, Sendable {
    var key: String
    var isOn = true
}

nonisolated enum SearchSort: String, Codable, Hashable, Sendable, CaseIterable {
    case match, priceLow, priceHigh, sqft, analysis

    var title: String {
        switch self {
        case .match: "Best match"
        case .priceLow: "Price: low to high"
        case .priceHigh: "Price: high to low"
        case .sqft: "Square feet"
        case .analysis: "Analysis"
        }
    }
}

nonisolated struct ScheduledTour: Codable, Hashable, Sendable {
    var listingID: String
    var day: String
    var time: String
}

nonisolated struct SearchState: Codable, Hashable, Sendable {
    var locations = [SearchRegions.defaultLocation]
    var filters = HomeFilters()
    var criteria: [String] = []
    /// Missing means nice-to-have.
    var modes: [String: CriterionMode] = [:]
    /// Criteria toggled off in the pill bar (kept, but not applied).
    var disabled: Set<String> = []
    var refinements: [SearchRefinement] = []
    var analysis: SearchAnalysis? = nil
    var sort: SearchSort = .match
    /// Which structured pills show in the bar ("price", "rooms").
    var exposed = ["price"]
    var savedSearch = false
    var tours: [ScheduledTour] = []
    var watches: [String] = []
    var hidden: Set<String> = []
    /// Homes the chat is pointing at (red pins).
    var highlighted: [String] = []

    static let initial = SearchState()

    /// The prototype's opening request: "Homes in Seattle under $1.3M with
    /// natural light, a finished basement, a large yard, a home office and a quiet street".
    static let introScenario: SearchState = {
        var s = SearchState()
        s.filters.maxPrice = 1_300_000
        s.criteria = HomeCatalog.knownCriteria
        return s
    }()

    func mode(of criterion: String) -> CriterionMode { modes[criterion] ?? .nice }

    /// Criteria that rank: on, and not dealbreakers.
    var scoringCriteria: [String] {
        criteria.filter { !disabled.contains($0) && mode(of: $0) != .deal }
    }

    /// Criterion pills + structured filters, for the Filters badge.
    var activeFilterCount: Int { criteria.count + filters.activeCount }

    // MARK: Labels (the prototype's pill and heading copy)

    /// "Seattle, WA" or "Ballard +2".
    var locationPillLabel: String {
        locations.count > 1 ? "\(locations[0]) +\(locations.count - 1)" : (locations.first ?? SearchRegions.defaultLocation)
    }

    /// "Seattle, WA", "Ballard & Fremont" or "3 areas".
    var locationPhrase: String {
        switch locations.count {
        case 0, 1: locations.first ?? SearchRegions.defaultLocation
        case 2: "\(locations[0]) & \(locations[1])"
        default: "\(locations.count) areas"
        }
    }

    /// "Up to $1.3M", "$800K–$1.3M", "$1M+"; nil when no price is set.
    var priceLabel: String? {
        let f = filters
        if f.minPrice > 0 && f.maxPrice > 0 { return "\(Self.money(f.minPrice))–\(Self.money(f.maxPrice))" }
        if f.maxPrice > 0 { return "Up to \(Self.money(f.maxPrice))" }
        if f.minPrice > 0 { return "\(Self.money(f.minPrice))+" }
        return nil
    }

    /// " under $1.3M", " over $1M", " from $800K to $1.3M" for headings.
    var pricePhrase: String {
        let f = filters
        if f.minPrice > 0 && f.maxPrice > 0 { return " from \(Self.money(f.minPrice)) to \(Self.money(f.maxPrice))" }
        if f.maxPrice > 0 { return " under \(Self.money(f.maxPrice))" }
        if f.minPrice > 0 { return " over \(Self.money(f.minPrice))" }
        return ""
    }

    /// "3+ bd, 2+ ba"; nil when neither is set.
    var roomsLabel: String? {
        let parts = [filters.beds > 0 ? "\(filters.beds)+ bd" : nil,
                     filters.baths > 0 ? "\(filters.baths.formatted())+ ba" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Pill label for a criterion: "Natural light", or "No busy street" for dealbreakers.
    func pillLabel(for criterion: String) -> String {
        let cap = criterion.prefix(1).uppercased() + criterion.dropFirst()
        return mode(of: criterion) == .deal ? "No \(criterion)" : cap
    }

    /// The prototype's `fmtK`: $1.3M, $1.25M, $950K.
    static func money(_ v: Int) -> String {
        v >= 1_000_000
            ? "$\((Double(v) / 1_000_000).formatted(.number.precision(.fractionLength(0...2)).grouping(.never)))M"
            : "$\(v / 1000)K"
    }

    // MARK: Undo

    /// The part of the search a chat turn can change, saved before each change.
    struct Snapshot: Codable, Hashable, Sendable {
        var locations: [String]
        var filters: HomeFilters
        var criteria: [String]
        var modes: [String: CriterionMode]
        var disabled: Set<String>
        var refinements: [SearchRefinement]
        var analysis: SearchAnalysis?
        var sort: SearchSort
    }

    var snapshot: Snapshot {
        Snapshot(locations: locations, filters: filters, criteria: criteria, modes: modes, disabled: disabled,
                 refinements: refinements, analysis: analysis, sort: sort)
    }

    mutating func restore(_ s: Snapshot) {
        locations = s.locations
        filters = s.filters
        criteria = s.criteria
        modes = s.modes
        disabled = s.disabled
        refinements = s.refinements
        analysis = s.analysis
        sort = s.sort
    }

    /// Drops toggled-off criteria, refinements and analysis before a new turn
    /// (the prototype's `prune`).
    mutating func prune() {
        criteria.removeAll { disabled.contains($0) }
        disabled = []
        if analysis?.isOn == false { analysis = nil }
        refinements.removeAll { !$0.isOn }
        highlighted = []
    }

    /// "Start fresh": clears area, filters and criteria; keeps saved homes and tours.
    mutating func clearSearch() {
        let keep = (tours, watches)
        self = SearchState()
        (tours, watches) = keep
    }
}

/// A home in the results with the criteria it matches.
nonisolated struct RankedHome: Identifiable, Hashable, Sendable {
    let listing: Listing
    let matched: [String]
    let missed: [String]

    var id: String { listing.id }
    var total: Int { matched.count + missed.count }
    /// "4/5"; nil when there are no ranking criteria.
    var matchLabel: String? { total > 0 ? "\(matched.count)/\(total)" : nil }
    var matchFraction: Double { total > 0 ? Double(matched.count) / Double(total) : 0 }
}

/// Pure search functions over a listing set.
nonisolated enum SearchEngine {
    static func passes(_ l: Listing, _ f: HomeFilters) -> Bool {
        if !f.status.isEmpty && f.status != "sale" { return false }
        if !f.types.isEmpty && !f.types.contains(l.propertyType) { return false }
        if f.minSqft > 0 && l.sqft < f.minSqft { return false }
        if f.maxSqft > 0 && l.sqft > f.maxSqft { return false }
        if f.hoa != 0 {
            let hoa = HomeCatalog.hoa(l)
            if f.hoa < 0 ? hoa != 0 : hoa > f.hoa { return false }
        }
        if f.daysOnMarket > 0 && l.daysOnMarket > f.daysOnMarket { return false }
        if !f.features.allSatisfy({ HomeCatalog.hasFeature(l, $0) }) { return false }
        if f.minPrice > 0 && l.price < f.minPrice { return false }
        if f.maxPrice > 0 && l.price > f.maxPrice { return false }
        if f.beds > 0 && l.beds < f.beds { return false }
        if f.baths > 0 && l.baths < f.baths { return false }
        if f.hotOnly && !l.isHotHome { return false }
        return true
    }

    /// Hidden homes, active refinements, must-haves and dealbreakers (the prototype's `refOk`).
    static func refinementsAllow(_ l: Listing, _ s: SearchState) -> Bool {
        if s.hidden.contains(l.id) { return false }
        for r in s.refinements where r.isOn && !r.listingIDs.contains(l.id) { return false }
        for c in s.criteria where !s.disabled.contains(c) {
            switch s.mode(of: c) {
            case .nice: continue
            case .must: if !HomeCatalog.has(l, c) { return false }
            case .deal: if HomeCatalog.has(l, c) { return false }
            }
        }
        return true
    }

    /// Homes in the search area that pass the filters, before ranking.
    static func visible(_ listings: [Listing], _ s: SearchState, regions: SearchRegions = .shared) -> [Listing] {
        regions.pool(listings, locations: s.locations).filter { passes($0, s.filters) && refinementsAllow($0, s) }
    }

    /// How many homes a state would show, for "Show N homes" and confirmations.
    static func count(_ listings: [Listing], _ s: SearchState) -> Int { visible(listings, s).count }

    /// Results ranked by the state's sort. Match ranks by criteria matched,
    /// then the original listing order.
    static func results(_ listings: [Listing], _ s: SearchState) -> [RankedHome] {
        let crits = s.scoringCriteria
        let order = Dictionary(uniqueKeysWithValues: listings.enumerated().map { ($0.element.id, $0.offset) })
        let ranked = visible(listings, s).map { l in
            let ok = crits.filter { HomeCatalog.has(l, $0) }
            return RankedHome(listing: l, matched: ok, missed: crits.filter { !ok.contains($0) })
        }
        let tie = { (a: RankedHome, b: RankedHome) in (order[a.id] ?? 0) < (order[b.id] ?? 0) }
        switch s.sort {
        case .analysis:
            // Lowest value first (closest, cheapest per sq ft, best transit); no value last.
            if let a = s.analysis.flatMap({ HomeAnalyses.all[$0.key] }) {
                let v = Dictionary(uniqueKeysWithValues: ranked.map { ($0.id, a.value($0.listing)) })
                return ranked.sorted { x, y in
                    switch (v[x.id] ?? nil, v[y.id] ?? nil) {
                    case let (p?, q?): return p != q ? p < q : tie(x, y)
                    case (.some, nil): return true
                    case (nil, .some): return false
                    case (nil, nil): return tie(x, y)
                    }
                }
            }
            fallthrough
        case .match:
            return ranked.sorted { $0.matched.count != $1.matched.count ? $0.matched.count > $1.matched.count : tie($0, $1) }
        case .priceLow:
            return ranked.sorted { $0.listing.price != $1.listing.price ? $0.listing.price < $1.listing.price : tie($0, $1) }
        case .priceHigh:
            return ranked.sorted { $0.listing.price != $1.listing.price ? $0.listing.price > $1.listing.price : tie($0, $1) }
        case .sqft:
            return ranked.sorted { $0.listing.sqft != $1.listing.sqft ? $0.listing.sqft > $1.listing.sqft : tie($0, $1) }
        }
    }

    /// Price histogram for the filter sheet: $50K bins from $200K to $1.5M,
    /// bar heights 8–100 (4 for empty bins).
    static func priceHistogram(_ listings: [Listing]) -> [(from: Int, to: Int, count: Int, height: Int)] {
        let bins = stride(from: 200_000, to: 1_500_000, by: 50_000).map { from in
            (from: from, to: from + 50_000, count: listings.filter { $0.price >= from && $0.price < from + 50_000 }.count)
        }
        let maxCount = max(1, bins.map(\.count).max() ?? 1)
        return bins.map { b in
            (b.from, b.to, b.count, b.count > 0 ? Int((8 + 92 * Double(b.count) / Double(maxCount)).rounded()) : 4)
        }
    }
}
