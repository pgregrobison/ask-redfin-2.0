import Foundation

// Text helpers ported from the iOS Vision prototype's router: regex
// shorthands, the price / beds / baths parser (`parseAsk`), the criteria
// splitter (`splitCrits`) and street matching. Patterns are the prototype's,
// translated from JavaScript to ICU syntax.

nonisolated extension String {
    /// Regex test (ICU), like JS `/p/.test(s)`.
    func rx(_ pattern: String, caseInsensitive: Bool = false) -> Bool {
        range(of: pattern, options: caseInsensitive ? [.regularExpression, .caseInsensitive] : .regularExpression) != nil
    }

    /// First match's groups (index 0 = whole match), like JS `s.match(/p/)`.
    func groups(_ pattern: String, caseInsensitive: Bool = false) -> [String?]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []),
              let m = re.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: self).map { String(self[$0]) } }
    }

    /// Regex replace-all.
    func replacingRx(_ pattern: String, with template: String, caseInsensitive: Bool = false) -> String {
        replacingOccurrences(of: pattern, with: template, options: caseInsensitive ? [.regularExpression, .caseInsensitive] : .regularExpression)
    }

    /// Replaces each match with " " unless `fn` returns false (the prototype's `eat`).
    func eating(_ pattern: String, _ fn: ([String?]) -> Bool) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return self }
        let ns = self as NSString
        var out = self
        var cuts: [NSRange] = []
        for m in re.matches(in: self, range: NSRange(location: 0, length: ns.length)) {
            let g: [String?] = (0..<m.numberOfRanges).map { i in m.range(at: i).location == NSNotFound ? nil : ns.substring(with: m.range(at: i)) }
            if fn(g) { cuts.append(m.range) }
        }
        for r in cuts.reversed() { out = (out as NSString).replacingCharacters(in: r, with: " ") }
        return out
    }

    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

nonisolated enum AskText {
    static func esc(_ s: String) -> String { NSRegularExpression.escapedPattern(for: s) }

    static func joinAnd(_ a: [String]) -> String {
        a.count < 2 ? (a.first ?? "") : a.dropLast().joined(separator: ", ") + " and " + a.last!
    }

    static func homes(_ n: Int) -> String { n == 1 ? "1 home" : "\(n) homes" }
    static func ranked(_ n: Int) -> String { n == 1 ? "your criterion" : "your \(n) criteria" }
    static func money(_ v: Int) -> String { SearchState.money(v) }

    // MARK: Features

    static let mainBedPattern = #"(primary|master|main[- ]floor|first[- ]floor|ground[- ]floor)\s+(bed|bedroom|suite)|(master|primary)\s+(bed(room)?\s+)?on\s+(the\s+)?main|bedroom on (the )?main|can'?t (do|handle|climb|manage) (the )?stairs|no stairs|single[- ]level|one[- ]level"#

    static let featurePatterns: [(String, String)] = [
        ("Garage", #"\bgarage\b"#), ("Air conditioning", #"\b(a/c|air[- ]?condition\w*)\b"#), ("Fireplace", #"\bfireplace\b"#),
        ("Washer/dryer", #"\b(washer|dryer|in[- ]unit laundry)\b"#), ("Waterfront", #"\bwaterfront\b"#), ("Pool", #"\bpool\b"#),
        ("Primary bed on main", mainBedPattern),
    ]

    static let featureText: [String: String] = [
        "Garage": "a garage", "Air conditioning": "air conditioning", "Fireplace": "a fireplace", "Washer/dryer": "a washer and dryer",
        "Waterfront": "waterfront", "Pool": "a pool", "Primary bed on main": "the primary bedroom on the main floor",
    ]

    static func features(in lo: String) -> [String] { featurePatterns.filter { lo.rx($0.1) }.map(\.0) }

    static func stripFeatures(_ s: String) -> String {
        featurePatterns.reduce(s.lowercased()) { $0.replacingRx($1.1, with: " ", caseInsensitive: true) }
    }

    // MARK: parseAsk

    struct Patch: Equatable {
        var minPrice: Int?
        var maxPrice: Int?
        var beds: Int?
        var baths: Double?
        var isEmpty: Bool { minPrice == nil && maxPrice == nil && beds == nil && baths == nil }
        var touchesPrice: Bool { minPrice != nil || maxPrice != nil }
        var touchesRooms: Bool { beds != nil || baths != nil }
    }

    struct Ask {
        var patch = Patch()
        var expose: [String] = []
        var rest = ""
        var has: Bool { !patch.isEmpty || !expose.isEmpty }
    }

    private static let numWord = #"(\d+(?:\.5)?|one|two|three|four|five|six)"#
    private static let bedWord = #"(?:beds?|bd|br|bdrms?|bedrooms?)"#
    private static let bathWord = #"(?:baths?|ba|bathrooms?)"#
    private static let notQty = #"(?!\s*\+?\s*(?:beds?|bd|br|bdrms?|bedrooms?|baths?|ba|bathrooms?|min\b|mins|minutes?|mi\b|miles?|sq|square|ft|feet|%|percent|days?|years?|stor(?:y|ies)|cars?))"#
    private static let pnum = #"\$?\s*(\d[\d,]*(?:\.\d+)?)\s*(k|mm?|mil(?:lion)?|thousand)?\b"#
    private static var prRx: String { pnum + notQty }
    private static let onlyPattern = #"^(?:(?:please |can you |let'?s |i want to |i'?d like to )?(?:add|show|use|set|open|filter(?: by| on)?|control|include|change|adjust|edit|update)\s+)?(?:the |my )?(?:filters? (?:for|by|on) )?(?:(?:number of )?((?:beds?|bedrooms?|baths?|bathrooms?)(?:\s*(?:/|and|&|,|or)\s*(?:beds?|bedrooms?|baths?|bathrooms?))?)|(price|budget))(?: filters?| range| count)?$"#

    static func numberWord(_ s: String) -> Double {
        ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6][s] ?? Double(s) ?? 0
    }

    /// Bare numbers under 20 read as millions ("1.1"), under 20,000 as thousands ("950").
    static func toPrice(_ n: String?, _ unit: String?) -> Int {
        var v = Double((n ?? "").replacingOccurrences(of: ",", with: "")) ?? 0
        let u = (unit ?? "").lowercased()
        if u.hasPrefix("m") { v *= 1e6 } else if u == "k" || u == "thousand" { v *= 1e3 } else if v < 20 { v *= 1e6 } else if v < 20000 { v *= 1e3 }
        return Int((v / 5000).rounded()) * 5000
    }

    static func parseAsk(_ t: String, _ f: HomeFilters) -> Ask {
        var s = " " + t.lowercased().replacingOccurrences(of: "’", with: "'").replacingRx(#"[.!?]+$"#, with: "") + " "
        var a = Ask()
        let main = s.rx(mainBedPattern)
        if !main, let only = s.trimmingCharacters(in: .whitespaces).groups(onlyPattern) {
            a.expose.append(only[1] != nil ? "rooms" : "price")
            return a
        }
        var p = Patch()
        s = s.eating(#"\b(?:any|no min(?:imum)?|remove(?: the)?|clear(?: the)?|drop(?: the)?|reset(?: the)?)\s+(?:number of\s+)?(beds?\s*(?:and|&|/)\s*baths?|bedrooms?\s*(?:and|&|/)\s*bathrooms?|beds?|bedrooms?|baths?|bathrooms?)(?:\s+(?:filter|min(?:imum)?|count))?\b"#) { m in
            if m[1]?.contains("bed") == true { p.beds = 0 }
            if m[1]?.contains("bath") == true { p.baths = 0 }
            return true
        }
        if !main {
            s = s.eating(#"\b(?:add\s+|with\s+|plus\s+)?(?:a|an|one|1|another)\s+(?:more|extra|additional)\s+(bed|bedroom|bath|bathroom)s?\b|\badd (?:a|an|one|another) (bed|bedroom|bath|bathroom)\b(?! on)"#) { m in
                if (m[1] ?? m[2] ?? "").contains("bed") { p.beds = f.beds + 1 } else { p.baths = f.baths + 1 }
                return true
            }
            s = s.eating(#"\b(?:one |1 )?(?:fewer|less)\s+(bed|bedroom|bath|bathroom)s?\b"#) { m in
                if m[1]?.contains("bed") == true { guard f.beds > 0 else { return false }; p.beds = max(0, f.beds - 1) }
                else { guard f.baths > 0 else { return false }; p.baths = max(0, f.baths - 1) }
                return true
            }
        }
        s = s.eating(#"(?:\b(?:at least|min(?:imum)?(?: of)?|more than|over)\s+)?\b"# + numWord + #"\s*\+?\s*(?:or more\s+)?"# + bedWord + #"\b"#) { m in
            p.beds = Int(numberWord(m[1] ?? "").rounded()); return true
        }
        s = s.eating(#"(?:\b(?:at least|min(?:imum)?(?: of)?|more than|over)\s+)?\b"# + numWord + #"\s*\+?\s*(?:or more\s+)?"# + bathWord + #"\b"#) { m in
            p.baths = numberWord(m[1] ?? ""); return true
        }
        s = s.eating(#"\b(?:beds?|bedrooms?)\s*(?:to|at|:|=|of|>=?|min(?:imum)?(?: of)?)\s*(?:at least\s*)?"# + numWord + #"\b(?!\s*(?:k|m|mil|million)\b)"#) { m in
            p.beds = Int(numberWord(m[1] ?? "").rounded()); return true
        }
        s = s.eating(#"\b(?:baths?|bathrooms?)\s*(?:to|at|:|=|of|>=?|min(?:imum)?(?: of)?)\s*(?:at least\s*)?"# + numWord + #"\b(?!\s*(?:k|m|mil|million)\b)"#) { m in
            p.baths = numberWord(m[1] ?? ""); return true
        }
        let ctx = s.rx(#"\b(price|priced|budget|cost|costs|spend|afford|max|cap)\b|\$|\d\s*(k|m|mil|million)\b"#)
        s = s.eating(#"\b(?:no|remove(?: the)?|clear(?: the)?|drop(?: the)?|get rid of(?: the)?|any|reset(?: the)?|lift(?: the)?)\s+(?:max(?:imum)?\s+|min(?:imum)?\s+|top\s+)?(?:price|budget)(?:\s+(?:limit|cap|filter|range|max|min|ceiling|floor))?\b(?!\s*(?:to|by|at|down|up|under|below|of|from)\b)"#) { m in
            let x = m[0] ?? ""
            if x.rx("min|floor") { p.minPrice = 0 } else if x.rx("max|top|limit|cap|ceiling") { p.maxPrice = 0 } else { p.minPrice = 0; p.maxPrice = 0 }
            return true
        }
        s = s.eating(#"\b(drop|lower|reduce|cut|bring down|decrease|raise|increase|bump(?: up)?|up|push|lift)\s+(?:the |my )?(?:max(?:imum)? |top )?(?:price|budget)(?: range| limit| cap)?\s+(?:down |up )?by\s+"# + prRx) { m in
            guard f.maxPrice > 0 else { return false }
            let d = toPrice(m[2], m[3]) * ((m[1] ?? "").rx("drop|lower|reduce|cut|down|decrease") ? -1 : 1)
            p.maxPrice = max(50000, f.maxPrice + d); return true
        }
        if ctx {
            s = s.eating(#"(?:\bbetween\s+|\bfrom\s+)?"# + prRx + #"\s*(?:-|–|to|and)\s*"# + prRx) { m in
                let lo = toPrice(m[1], m[2]), hi = toPrice(m[3], m[4])
                guard hi > lo else { return false }
                p.minPrice = lo; p.maxPrice = hi; return true
            }
        }
        s = s.eating(#"\b(?:drop|lower|reduce|cut|bring|decrease|raise|increase|bump|up|push|lift|change|set|move|make|adjust|update|put|cap|limit|keep|stretch|go)\s+(?:it\s+|down\s+|up\s+)?(?:the |my |our )?(?:max(?:imum)? |top )?(price|budget)?(?: range| limit| cap| max| ceiling)?\s*(?:(?:from|of)\s+\$?\s*\d[\d,]*(?:\.\d+)?\s*(?:k|mm?|mil(?:lion)?)?\s+)?(?:down |up )?(?:to|at|under|below)\s+"# + prRx) { m in
            if m[1] == nil && m[3] == nil && !(m[0] ?? "").contains("$") && !ctx { return false }
            p.maxPrice = toPrice(m[2], m[3]); return true
        }
        s = s.eating(#"\b(?:under|below|less than|no more than|at most|up to|not over|max(?:imum)?(?: price)?(?: of| is| at| to)?|budget(?: is| of| to| at| around| about)?|price(?: max| cap| limit| ceiling)?(?:\s+(?:to|at|of|is|under|below|around|about))?|cap(?: it)? at|top(?:s| out)? at|ceiling(?: of)?)\s*"# + prRx) { m in
            p.maxPrice = toPrice(m[1], m[2]); return true
        }
        s = s.eating(pnum + #"\s*(?:max|or less|or under|or below|tops|ceiling)\b"#) { m in
            p.maxPrice = toPrice(m[1], m[2]); return true
        }
        s = s.eating(#"\b(?:over|above|more than|at least|min(?:imum)?(?: price)?(?: of| is| at| to)?|starting at|no less than|(?:price )?floor(?: of| to| at)?)\s*"# + prRx) { m in
            p.minPrice = toPrice(m[1], m[2]); return true
        }
        if ctx {
            s = s.eating(pnum + #"\s*(?:\+|and up|or more)(?!\s*"# + bedWord + #"|\s*"# + bathWord + ")") { m in
                p.minPrice = toPrice(m[1], m[2]); return true
            }
        }
        if let mx = p.maxPrice, mx > 0, (p.minPrice ?? f.minPrice) > mx { p.minPrice = 0 }
        let effMax = p.maxPrice ?? f.maxPrice
        if let mn = p.minPrice, mn > 0, effMax > 0, effMax < mn { p.maxPrice = 0 }
        a.patch = p
        a.rest = s.replacingRx(#"\s{2,}"#, with: " ").trimmingCharacters(in: .whitespaces)
        return a
    }

    // MARK: splitCrits

    private static let leadPattern = #"^(?:ok(?:ay)?|so|also|and|now|then|hmm+|actually|please|hey|yes|yeah|great|cool|let'?s|let us|lets|can you|could you|would you|will you|i'?d (?:also )?(?:like|love|want)|i would (?:like|love)|i (?:also )?(?:want|need|prefer)|we (?:also )?(?:want|need|prefer)|i'?m (?:looking for|after)|looking for|show me|find me|get me|give me|search for|find|show|add|make|include|throw in|put in|toss in|plus|(?:homes?|houses?|places?|listings?|properties)(?= (?:with|that|which|having|where)\b|$)|something|that|which|with|having|has|have|had|it should have|should have|must have|needs?|requires?|to have|for|filter (?:by|for|to)|only)\b[\s,:]*"#
    private static let trailPattern = #"[\s,]*(?:too|as well|also|please|thanks|thank you|if possible|ideally|to (?:my|the) (?:search|list|criteria)|to (?:it|that)|as (?:criteria|a criterion|well)|in (?:it|the home|the house))$"#
    private static let stopWords: Set<String> = ["it", "that", "this", "them", "more", "homes", "home", "houses", "house", "stuff", "things", "something", "one", "ones", "some", "any", "others", "other", "has", "have", "with", "and", "the", "for", "also", "too", "under", "over", "set", "change", "make", "update", "add", "show", "drop", "lower", "raise", "filter", "filters"]
    static let questionPattern = #"^(?:which|what|whats|what's|does|do|did|is|are|was|were|how|why|when|where|who|can i|could i|should|will|would it|tell me|explain)\b"#

    /// "let's add a basement and vaulted ceilings" -> ["basement", "vaulted ceilings"]
    static func splitCriteria(_ t: String) -> [String] {
        var s = t.lowercased().replacingOccurrences(of: "’", with: "'").replacingRx(#"[.!?]+$"#, with: "").trimmingCharacters(in: .whitespaces)
        if s.isEmpty || s.rx(questionPattern) { return [] }
        var prev: String
        repeat { prev = s; s = s.replacingRx(leadPattern, with: "").replacingRx(trailPattern, with: "").trimmingCharacters(in: .whitespaces) } while s != prev
        var out: [String] = []
        let parts = s.replacingRx(#"\s*(?:,|;|&|\+|\band also\b|\bas well as\b|\balong with\b|\bplus\b|\band\b|\bwith\b|\bor\b)\s*"#, with: "\u{1F}").components(separatedBy: "\u{1F}")
        for x in parts {
            var q = x.trimmingCharacters(in: .whitespaces), v: String
            repeat {
                v = q
                q = q.replacingRx(#"^(?:a|an|the|some|any|lots of|plenty of|and|or|maybe|really|definitely)\s+"#, with: "")
                    .replacingRx(leadPattern, with: "").replacingRx(trailPattern, with: "").trimmingCharacters(in: .whitespaces)
            } while q != v
            q = q.replacingRx(#"[^a-z0-9\s\-/']"#, with: "").replacingRx(#"\s{2,}"#, with: " ").trimmingCharacters(in: .whitespaces)
            if q.count > 2 && !stopWords.contains(q) && !out.contains(q) { out.append(q) }
        }
        return out
    }

    // MARK: Streets

    /// "1537 Thorndyke Ave W" -> "Thorndyke Ave W"
    static func road(of l: Listing) -> String {
        l.address.replacingRx(#"^[\d-]+[A-Z]?\s+"#, with: "").replacingRx(#"\s+(#|unit|apt|suite)\s*\S*$"#, with: "", caseInsensitive: true).trimmingCharacters(in: .whitespaces)
    }

    private static let directionWords = #"^(n|s|e|w|ne|nw|se|sw|st|ave|avenue|street|way|pl|rd|dr|blvd)$"#

    /// The distinctive word of a road ("thorndyke").
    static func core(of road: String) -> String {
        (road.split(separator: " ").map(String.init).first { !$0.rx(directionWords, caseInsensitive: true) } ?? road).lowercased()
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var d = Array(0...b.count)
        for i in 1...max(a.count, 1) where !a.isEmpty {
            var p = d[0]; d[0] = i
            for j in 1...max(b.count, 1) where !b.isEmpty {
                let t = d[j]
                d[j] = min(d[j] + 1, d[j - 1] + 1, p + (a[i - 1] == b[j - 1] ? 0 : 1))
                p = t
            }
        }
        return d[b.count]
    }

    /// A home whose street number and road word both appear in the text.
    static func addressHits(_ lo: String, in listings: [Listing]) -> [Listing] {
        listings.filter { l in
            let no = l.address.lowercased().split(separator: " ").first.map(String.init) ?? ""
            return !no.isEmpty && lo.rx(#"\b"# + esc(no) + #"\b"#) && lo.contains(core(of: road(of: l)))
        }
    }
}
