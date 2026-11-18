import Foundation

/// Dream Home settings that aren't part of the search itself (the
/// prototype's `dreamX`). Saved with the search so each chat keeps its own.
nonisolated struct DreamExtras: Codable, Hashable, Sendable {
    enum Timeline: String, Codable, CaseIterable, Sendable {
        case soon = "less_than_6_months", later = "6_months_to_2_years", dreaming = "just_dreaming"
        var label: String {
            switch self {
            case .soon: "in less than 6 months"
            case .later: "in 6 months to 2 years"
            case .dreaming: "someday"
            }
        }
        var detail: String? { self == .dreaming ? "Just dreaming for now" : nil }
    }

    enum Alerts: String, Codable, CaseIterable, Sendable {
        case instant, daily, off
        var title: String { rawValue.capitalizedFirst }
        var detail: String {
            switch self {
            case .instant: "As soon as a new home matches"
            case .daily: "One summary each morning"
            case .off: "No alerts. Your dream home still shapes search"
            }
        }
    }

    enum Tier: String, Codable, CaseIterable, Sendable {
        case affordable, stretch, ambitious
        var title: String { rawValue.capitalizedFirst }
        var detail: String {
            switch self {
            case .affordable: "Comfortable monthly payment"
            case .stretch: "Tighter budget, still approvable"
            case .ambitious: "Needs a bigger down payment or rate drop"
            }
        }
    }

    var name = "My dream home"
    var timeline: Timeline = .dreaming
    var alerts: Alerts = .instant
    /// Buying-power tiers you've included (the top included tier sets your max price).
    var includedTiers: [Tier] = [.affordable, .stretch]
    /// Recommendations you've dismissed (criterion text).
    var dismissed: [String] = []
    /// Inspiration photos you've liked (bundled photo names).
    var inspiration: [String] = []
}

/// One pill in a Dream Home bucket.
nonisolated struct DreamItem: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable { case beds, baths, sqft, criterion(String) }
    var kind: Kind
    var label: String
    /// Came from your search rather than something you added here.
    var fromSearch: Bool
    var id: String {
        switch kind {
        case .beds: "beds"
        case .baths: "baths"
        case .sqft: "sqft"
        case .criterion(let c): "c:" + c
        }
    }
    /// Beds, baths and size are filters, so they're always must-haves.
    var isFilter: Bool { if case .criterion = kind { return false }; return true }
}

/// A suggestion with evidence: "3 of the 4 homes you saved have it".
nonisolated struct DreamRecommendation: Identifiable, Hashable, Sendable {
    var criterion: String
    var evidence: String
    var id: String { criterion }
}

/// Reads and edits the dream home through the search, two ways like the
/// prototype's `dreamOf` / `fromDream`.
nonisolated extension SearchState {
    var dreamMustHaves: [DreamItem] {
        var out: [DreamItem] = []
        if filters.beds > 0 { out.append(DreamItem(kind: .beds, label: "\(filters.beds)+ beds", fromSearch: true)) }
        if filters.baths > 0 { out.append(DreamItem(kind: .baths, label: "\(filters.baths.formatted())+ baths", fromSearch: true)) }
        if filters.minSqft > 0 { out.append(DreamItem(kind: .sqft, label: "\(filters.minSqft.formatted())+ sq ft", fromSearch: true)) }
        return out + criteriaItems(.must)
    }
    var dreamNiceToHaves: [DreamItem] { criteriaItems(.nice) }
    var dreamDealBreakers: [DreamItem] { criteriaItems(.deal) }

    private func criteriaItems(_ mode: CriterionMode) -> [DreamItem] {
        criteria.filter { !disabled.contains($0) && self.mode(of: $0) == mode }.map {
            DreamItem(kind: .criterion($0), label: $0.capitalizedFirst, fromSearch: HomeCatalog.knownCriteria.contains($0))
        }
    }

    var dreamPreferenceCount: Int { dreamMustHaves.count + dreamNiceToHaves.count + dreamDealBreakers.count }

    /// Known criteria that most of your saved homes have (needs 2+ saved, 60%+).
    func dreamRecommendations(saved: [Listing]) -> [DreamRecommendation] {
        guard saved.count >= 2 else { return [] }
        return HomeCatalog.knownCriteria.filter { !criteria.contains($0) && !dream.dismissed.contains($0) }.compactMap { c in
            let n = saved.filter { HomeCatalog.has($0, c) }.count
            return Double(n) / Double(saved.count) >= 0.6
                ? DreamRecommendation(criterion: c, evidence: "\(n) of the \(saved.count) homes you saved have it") : nil
        }
    }

    // MARK: Buying power

    /// Tier ranges around your max price, rounded to $10K (the prototype's estimate).
    var dreamTierRanges: [DreamExtras.Tier: ClosedRange<Int>]? {
        let mx = dreamBaseMax
        guard mx > 0 else { return nil }
        let r = { (v: Double) in Int((v / 10_000).rounded()) * 10_000 }
        return [.affordable: 0...r(Double(mx) * 0.9), .stretch: r(Double(mx) * 0.9)...mx, .ambitious: mx...r(Double(mx) * 1.1)]
    }

    /// The max price the tiers are built around: your filter max, adjusted
    /// back from whichever tier currently sets it.
    private var dreamBaseMax: Int {
        let mx = filters.maxPrice
        guard mx > 0 else { return 0 }
        if dream.includedTiers.contains(.ambitious) { return Int((Double(mx) / 1.1 / 10_000).rounded()) * 10_000 }
        if !dream.includedTiers.contains(.stretch) && dream.includedTiers.contains(.affordable) { return Int((Double(mx) / 0.9 / 10_000).rounded()) * 10_000 }
        return mx
    }

    /// "Calculate": with no max price yet, start from the Seattle median.
    mutating func calculateBuyingPower(median: Int) {
        if filters.maxPrice == 0 { filters.maxPrice = Int((Double(median) / 10_000).rounded()) * 10_000 }
        dream.includedTiers = [.affordable, .stretch]
    }

    mutating func setTier(_ t: DreamExtras.Tier, included: Bool) {
        guard let ranges = dreamTierRanges else { return }
        var tiers = Set(dream.includedTiers)
        if included { tiers.insert(t) } else { tiers.remove(t) }
        if tiers.isEmpty { return }
        dream.includedTiers = DreamExtras.Tier.allCases.filter(tiers.contains)
        filters.maxPrice = dream.includedTiers.compactMap { ranges[$0]?.upperBound }.max() ?? filters.maxPrice
    }

    mutating func clearBuyingPower() {
        filters.maxPrice = 0
        filters.minPrice = 0
        dream.includedTiers = [.affordable, .stretch]
    }

    // MARK: Editing

    enum DreamBucket: Hashable, Sendable { case must, nice, deal }

    /// Adds typed text to a bucket: "3 beds" sets a filter, anything else is a criterion.
    mutating func addDream(_ text: String, to bucket: DreamBucket) {
        let l = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !l.isEmpty else { return }
        if let m = l.groups(#"^(\d+)\+?\s*(beds?|bedrooms?)$"#), let n = Int(m[1] ?? "") { filters.beds = n; return }
        if let m = l.groups(#"^(\d+(?:\.\d)?)\+?\s*(baths?|bathrooms?)$"#), let n = Double(m[1] ?? "") { filters.baths = n; return }
        if let m = l.groups(#"^([\d,]+)\+?\s*sq\.? ?ft$"#), let n = Int((m[1] ?? "").replacingOccurrences(of: ",", with: "")) { filters.minSqft = n; return }
        if !criteria.contains(l) { criteria.append(l) }
        disabled.remove(l)
        setMode(l, bucket)
    }

    mutating func moveDream(_ item: DreamItem, to bucket: DreamBucket) {
        guard case .criterion(let c) = item.kind else { return }
        setMode(c, bucket)
    }

    mutating func removeDream(_ item: DreamItem) {
        switch item.kind {
        case .beds: filters.beds = 0
        case .baths: filters.baths = 0
        case .sqft: filters.minSqft = 0
        case .criterion(let c):
            criteria.removeAll { $0 == c }
            modes[c] = nil
            disabled.remove(c)
        }
    }

    /// Reorders criteria within a bucket (order is how they're listed everywhere).
    mutating func moveDream(_ item: DreamItem, by offset: Int, in bucket: [DreamItem]) {
        guard case .criterion(let c) = item.kind, let i = bucket.firstIndex(of: item) else { return }
        let j = i + offset
        guard bucket.indices.contains(j), case .criterion(let other) = bucket[j].kind,
              let a = criteria.firstIndex(of: c), let b = criteria.firstIndex(of: other) else { return }
        criteria.swapAt(a, b)
    }

    private mutating func setMode(_ c: String, _ bucket: DreamBucket) {
        switch bucket {
        case .must: modes[c] = .must
        case .nice: modes[c] = nil
        case .deal: modes[c] = .deal
        }
    }
}
