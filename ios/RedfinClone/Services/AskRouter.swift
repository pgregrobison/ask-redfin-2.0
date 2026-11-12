import Foundation

/// The iOS Vision prototype's intent router (`route`, `h2`, `h3`,
/// `runBasic`), ported to Swift. Given a request and the current search it
/// returns the confirmations, the reply, the next search state and any
/// CTA / widget. It remembers the home and list the conversation is
/// pointing at so follow-ups ("and the next one?", "does it have a garage?")
/// work, and pending offers so "yes" does what it offered.
@MainActor
final class AskRouter {
    private let catalog: [Listing]
    private let favorites: () -> Set<String>

    // Conversation memory
    private(set) var lastHome: String?
    private(set) var lastList: [String] = []
    private var lastAttr: (attr: Attr, dirMax: Bool, ids: [String], vals: [String: Double])?
    private var offer: ((SearchState) -> AskReply)?
    private var expandOffer: ((SearchState) -> AskReply)?
    private(set) var pick: TourPick?
    private(set) var itinerary: TourPlan?
    private(set) var debrief: [String]?
    private var query = ""

    static let agentName = "Jordan Lee", agentFirst = "Jordan"
    static let rate = 0.065, rateText = "6.5%"
    static let photoStyles: [(key: String, text: String)] = [
        ("craftsman", "a Craftsman-style exterior with a covered front porch"), ("brick", "a brick exterior with traditional lines"),
        ("modern", "a modern exterior with clean lines and large windows"), ("shingle", "shingle siding with a cottage feel"),
        ("farmhouse", "a farmhouse look with board-and-batten siding"), ("townhouse", "a multi-level townhouse"),
        ("cottage", "a small painted cottage"), ("split", "a split-level layout"), ("stucco", "a single-level stucco ranch"),
    ]
    static let phrase: [String: String] = [
        "natural light": "big south-facing windows", "finished basement": "a finished basement with a guest room",
        "large yard": "a large fenced backyard", "home office": "a dedicated office off the living room", "quiet street": "a quiet, tree-lined street",
    ]

    init(listings: [Listing], favorites: @escaping () -> Set<String>) {
        catalog = listings
        self.favorites = favorites
    }

    /// Clears what the conversation was pointing at (new chat, fresh start).
    func reset() {
        lastHome = nil; lastList = []; lastAttr = nil; offer = nil; pick = nil; itinerary = nil; debrief = nil
    }

    // MARK: - Helpers

    private func H(_ id: String) -> Listing? { catalog.first { $0.id == id } }
    private func visible(_ s: SearchState) -> [Listing] { SearchEngine.results(catalog, s).map(\.listing) }
    private func count(_ s: SearchState) -> Int { SearchEngine.count(catalog, s) }
    private func pool(_ s: SearchState) -> [Listing] { SearchRegions.shared.pool(catalog, locations: s.locations) }
    private func pruned(_ s: SearchState) -> SearchState { var n = s; n.prune(); return n }

    private func street(_ l: Listing) -> String { l.address }
    private func sqftText(_ l: Listing) -> String { l.sqft > 0 ? l.sqft.formatted() : "—" }
    private func sqf(_ v: Double) -> String { Int(v).formatted() + " sq ft" }
    private func num(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : v.formatted() }
    private func cents(_ v: Double) -> String { "$" + Int(v.rounded()).formatted() }

    private func list(_ xs: [Listing]) -> String {
        let a = xs.prefix(xs.count > 5 ? 4 : 5).map { "\(street($0)) (\($0.formattedPrice))" }
        return xs.count > 5 ? a.joined(separator: ", ") + " and \(xs.count - 4) more" : AskText.joinAnd(Array(a))
    }

    private func noneOf(_ n: Int, _ what: String) -> String {
        n == 1 ? "The 1 home in your results isn’t " + what : "None of the \(n) homes in your results are " + what
    }

    private func fast(_ r: AskReply) -> AskReply { var r = r; r.slow = false; r.steps = ["Thinking"]; return r }

    private func slow(_ steps: [String], _ n: Int, _ r: AskReply) -> AskReply {
        var r = r
        r.slow = true
        r.steps = ["Reading your " + (n == 1 ? "1 result" : "\(n) results")] + steps
        r.workDone = r.workDone ?? "Checked \(AskText.homes(n))"
        return r
    }

    private func bot(_ text: String, surface: Bool = false, tools: [String] = [], next: SearchState? = nil,
                     cta: AskCTA? = nil, widget: AskWidget? = nil, sugs: [String] = []) -> AskReply {
        var r = AskReply(bot: text)
        r.tools = tools; r.surface = surface; r.next = next; r.cta = cta; r.widget = widget; r.suggestions = sugs
        return r
    }

    /// Highlights homes (replacing earlier highlights) and remembers the list.
    private func hi(_ s: SearchState, _ ids: [String], list: [String]? = nil) -> SearchState {
        if ids.count == 1 { lastHome = ids[0] }
        if let list { lastList = list }
        var n = pruned(s)
        n.highlighted = ids
        return n
    }

    private func addRef(_ s: SearchState, id: String, label: String, _ xs: [Listing]) -> SearchState {
        var n = pruned(s)
        n.refinements.removeAll { $0.id == id }
        n.refinements.append(SearchRefinement(id: id, label: label, listingIDs: xs.map(\.id)))
        lastList = xs.map(\.id)
        return n
    }

    private func scoring(_ s: SearchState) -> [String] { s.scoringCriteria }

    private func bestOf(_ xs: [Listing], _ s: SearchState) -> [(x: Listing, ok: [String])] {
        let sc = scoring(s), favs = favorites()
        return xs.enumerated().map { e in (i: e.offset, x: e.element, ok: sc.filter { c in HomeCatalog.has(e.element, c) }) }
            .sorted { a, b in
                if a.ok.count != b.ok.count { return a.ok.count > b.ok.count }
                let fa = favs.contains(a.x.id), fb = favs.contains(b.x.id)
                if fa != fb { return fa }
                return a.i < b.i
            }
            .map { ($0.x, $0.ok) }
    }

    // MARK: - Route

    func route(_ tIn: String, _ s: SearchState) -> AskReply {
        let t = tIn.trimmingCharacters(in: .whitespacesAndNewlines).replacingRx(#"[.!?]+$"#, with: "")
        let lo = t.lowercased().replacingOccurrences(of: "’", with: "'")
        query = lo
        var r = routeInner(t, lo, s)
        if r.steps.isEmpty { r.steps = ["Thinking"] }
        return r
    }

    private func routeInner(_ t: String, _ lo: String, _ s: SearchState) -> AskReply {
        let vis = visible(s), N = vis.count
        let pending = offer
        offer = nil
        if let pending, lo.rx(#"^(yes|yeah|yep|yup|sure|ok(ay)?|please|do it|go ahead|sounds good|let'?s do it|absolutely)\b"#) {
            return pending(s)
        }

        if lo.rx(#"\b(pick up where|where (i|we) left off|resume (my|our)|(my|our) (last|previous) (search|chat|session)|last time|what did (i|we) (look at|save|talk about))\b"#) {
            var r = AskReply(bot: ""); r.action = .recall; return fast(r)
        }
        if lo.rx(#"\b(start (a )?fresh|start from scratch|start (a )?new search|forget (everything|me|my search)|clear (my )?(memory|history|everything))\b"#) {
            return fast(freshStart(s, full: lo.rx(#"\b(forget (everything|me)|clear (my )?(memory|history|everything))\b"#)))
        }

        expandOffer = { [weak self] st in self?.expand(st, then: nil) ?? AskReply(bot: "") }

        // Places named in the request, longest first.
        let placeNames = SearchRegions.shared.places.filter { $0.kind != "School district" }.map(\.name).sorted { $0.count > $1.count }
        let placeRx = { (nm: String) in #"\b"# + AskText.esc(nm.replacingOccurrences(of: ", WA", with: "").lowercased()) + #"\b"# }
        let placeHits = placeNames.filter { lo.rx(placeRx($0)) }
        let nearRx = #"\b(close|closest|closer|near|nearest|nearby|distance|walk(ing|able)?|minutes? (from|to)|\d+\s*-?\s*(min|mins|minutes)\b|drive|driving|proximity|commute|to get to)\b"#
        let newsRx = #"\b(new search|start (a )?new|start over|fresh search|search again|instead|switch (the )?(search |area )?to|move (the )?(search|map) to|only (in|show)|just (in|show)|change (the )?(area|location) to|focus (on|in)|narrow (it )?(down )?to|zero in on)\b"#
        let nearPhrase = lo.rx(nearRx), newSearch = lo.rx(newsRx)
        let addArea = lo.rx(#"\b(add|include|also (search|look|show)|plus|as well)\b"#)
        let broaden = lo.rx(#"\b(expand|widen|broaden|zoom out|bigger area|larger area|wider area|more (homes|results|listings|options)|other (homes|areas|neighbou?rhoods)|search (more|wider|further)|look (further|wider|elsewhere)|beyond)\b"#)
        let searchVerb = lo.rx(#"\b(search|look|show|find|see|browse|homes?|houses?|listings?)\b"#)
        let wideRx = #"\b(in |across |for )?(all of seattle|(the )?(whole|entire) (city|seattle)|all (the )?(homes|listings) in seattle|seattle-wide|citywide)\b"#

        if lo.rx(wideRx), !s.locations.contains(SearchRegions.defaultLocation) {
            let rest = t.replacingRx(wideRx, with: "", caseInsensitive: true).replacingRx(#"\s{2,}"#, with: " ").trimmingCharacters(in: .whitespaces)
            let bare = rest.isEmpty || rest.rx(#"^(search|show( me)?|look( at)?|see|browse|expand( to)?|widen( to)?|homes|houses|listings)( (homes|houses|listings))?$"#, caseInsensitive: true)
            return fast(moveTo(s, [SearchRegions.defaultLocation], replace: false, then: bare ? nil : rest))
        }

        let stripPlace = { (s0: String, names: [String]) -> String in
            names.reduce(s0) { acc, nm in
                acc.replacingRx(#"\b(?:in|near|around|at|to)?\s*"# + AskText.esc(nm.replacingOccurrences(of: ", WA", with: "")) + #"(?:,? ?wa)?\b"#, with: " ", caseInsensitive: true)
            }
            .replacingRx(#"\b(and|or|&)\s*(?=$|\s)"#, with: " ", caseInsensitive: true)
            .replacingRx(#"\s{2,}"#, with: " ").trimmingCharacters(in: .whitespaces)
        }

        // Compound requests: "Ballard, and only townhouses under $1M".
        let clauses = t.replacingRx(#"\s*[,;]\s*(?:and\s+|then\s+)?|\s+(?:and then|then|and also|also|and|plus)\s+"#, with: "\u{1F}", caseInsensitive: true)
            .components(separatedBy: "\u{1F}").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !placeHits.isEmpty && clauses.count > 1 {
            let pc = clauses.filter { c in let l = c.lowercased(); return placeHits.contains { l.rx(placeRx($0)) } && !l.rx(nearRx) }
            if !pc.isEmpty && pc.count < clauses.count {
                let ps = placeHits.filter { nm in pc.contains { $0.lowercased().rx(placeRx(nm)) } }
                let fill = #"^(?:(?:please|can you|could you|let'?s|and|then|now|narrow|it|down|to|focus|on|in|zero|switch|move|change|the|search|area|map|location|show|me|homes?|houses?|listings?|look|at|just|only|instead|over|for)\s*)*$"#
                let rest = (pc.map { stripPlace($0, ps) } + clauses.filter { !pc.contains($0) })
                    .filter { !$0.isEmpty && !$0.rx(fill, caseInsensitive: true) }.joined(separator: " and ")
                return fast(moveTo(s, ps, replace: pc.contains { $0.lowercased().rx(newsRx) }, then: rest.isEmpty ? nil : rest))
            }
        }

        if !placeHits.isEmpty && !nearPhrase && (newSearch || addArea || broaden || searchVerb) {
            let left = stripPlace(t, placeHits)
            return fast(moveTo(s, placeHits, replace: newSearch, then: AskText.parseAsk(left, s.filters).has ? left : nil))
        }
        if broaden && placeHits.isEmpty { return fast(expand(s, then: nil)) }
        if newSearch && placeHits.isEmpty && lo.rx(#"\b(new search|start over|start (a )?new|fresh search)\b"#) {
            return fast(bot("Where would you like to search? I’ll keep your filters and criteria.", surface: true))
        }

        let wide = lo.rx(#"\b(all of seattle|(the )?(whole|entire) (city|area|seattle)|everywhere|all (the )?(homes|listings) in seattle)\b"#)
        let scope = wide ? "I can only check the \(N) homes in your current results, not all of Seattle. Narrow the area or widen your filters to check more." : ""
        let pre = wide ? scope + " " : ""
        let feats = AskText.features(in: lo)

        if let r = h2(lo, vis, s, pre: pre) { return r }
        if let r = h3(lo, vis, s, pre: pre) { return r }

        // Guardrails
        if lo.rx(#"\b(safe|safest|safety|sketchy|crime|criminal|dangerous|(bad|rough) (area|neighbou?rhood)s?)\b"#) {
            return fast(bot("I can’t rate how safe an area is. The Seattle Police Department publishes neighborhood crime data if you’d like to review it yourself. I can help with things like transit scores, nearby parks or distance to a place you visit often.",
                            surface: true, next: pruned(s), sugs: ["Which has the best transit score?", "Sort by distance to parks", "Closest to Green Lake first"]))
        }
        if lo.rx(#"\b(good|great|best|ideal) for (a )?(famil(y|ies)|kids|children)\b|\b(family|kid)[- ]friendly\b"#) {
            let xs = vis.filter { $0.beds >= 3 && HomeCatalog.has($0, "large yard") }
            let text = "I can’t say who an area suits, but I can point to home features. " + (xs.isEmpty ? "None have both 3+ bedrooms and a large yard." : pre + "\(xs.count)" + (xs.count == 1 ? " home has" : " homes have") + " 3+ bedrooms and a large yard: " + list(xs) + ".") + " Want me to sort by distance to schools?"
            return slow(["Checking bedrooms and yards", "Comparing homes"], N, bot(text, next: hi(s, xs.map(\.id), list: xs.map(\.id)), sugs: ["Sort by distance to schools", "Sort by distance to parks", "Does the cheapest one have a garage?"]))
        }
        if lo.rx(#"\b(good|great|best|better|fair) (deal|value|price)s?\b|\bunderpriced\b|\bbargains?\b|\bsteal\b|\boverpriced\b|\bworth (it|the price)\b"#) {
            let ss = lo.rx(#"sh(or|ro)t[- ]?sales?"#) ? vis.filter { $0.facts?.isShortSale == true } : []
            var n = pruned(s); n.highlighted = ss.map(\.id)
            let text = (ss.isEmpty ? "" : "\(ss.count) of your results " + (ss.count == 1 ? "is a short sale" : "are short sales") + ": " + list(ss) + ". Short sales need lender approval, so closing often takes longer. ") + "I can’t say whether a home is a good deal. A Redfin agent can pull recent nearby sales so you can compare. I can also color pins by price per sq ft."
            return fast(bot(text, surface: true, next: n, cta: AskCTA(label: "Connect with \(Self.agentFirst)", kind: .agent), sugs: ["Color pins by price per sq ft", "What’s the average price per sq ft?"]))
        }

        // Structured filters with criteria: "3 beds under $1.2M with a yard".
        let ask = AskText.parseAsk(t, s.filters)
        if ask.has && !lo.rx(#"\b(afford|mortgage|monthly|payments?|tours?|similar|like (this|that|it)|drive|driving|commute|walk(ing)?|transit|minutes?|cheapest|most expensive|biggest|smallest|average|median|how many)\b"#) {
            if !placeHits.isEmpty && !nearPhrase { return fast(moveTo(s, placeHits, replace: newSearch, then: stripPlace(t, placeHits))) }
            let mode: CriterionMode = lo.rx(#"\bmust[- ]?haves?\b|\bmust have\b|\b(needs?|has|have) to have\b"#) ? .must : lo.rx(#"\bdeal ?breakers?\b"#) ? .deal : .nice
            let fs = AskText.features(in: ask.rest)
            let cs = AskText.splitCriteria(AskText.stripFeatures(ask.rest).replacingRx(#"\bmust[- ]?haves?\b|\bdeal ?breakers?\b|\bnice[- ]to[- ]haves?\b"#, with: " ")).map { normCrit($0, s, loose: false) }
            return fast(applyAsk(s, patch: ask.patch, expose: ask.expose, feats: fs, crits: cs, mode: mode))
        }

        let addrHit = AskText.addressHits(lo, in: catalog).first
        let addrLike = lo.rx(#"\b\d{2,5}\s+((n|s|e|w|nw|ne|sw|se)\s+)?[a-z0-9]+\s+(st|street|ave|avenue|blvd|way|pl|place|rd|road|dr|drive|ct|ln)\b"#)
        let lastId0 = (s.highlighted.count == 1 ? s.highlighted.first : nil) ?? lastHome
        let tgt: Listing? = {
            if let a = addrHit, vis.contains(a) { return a }
            if lo.rx(#"\b(top|best) (match|one|home|pick|fit)\b"#), !vis.isEmpty { return bestOf(vis, s).first?.x }
            if lo.rx(#"\b(first|1st) (one|home|house|listing)\b"#) { return vis.first }
            if let id = lastId0, lo.rx(#"\b(it|this|that|them)\b"#) { return H(id) }
            return nil
        }()

        // "Quiet street is a must-have", "Dealbreaker: a busy street", "No HOA"...
        let special = #"sh(or|ro)t[- ]?sale|\bcars?\b|stairs|\bhoa\b|\bfees?\b"#
        let mM = lo.groups(#"^(?:i )?(?:must|has to|have to|needs? to|gotta) have (.+)$"#) ?? lo.groups(#"^(?:make )?(.+?) (?:is |are )?(?:a )?must(?:[- ]haves?)?$"#)
        let noThanks = lo.rx(#"^(no|nope)\b[ ,]*(thanks?|thank you|worries|problem|need|that'?s (ok|fine))"#)
        let dM = lo.groups(#"^(?:make )?(.+?) (?:is |are )?(?:a )?deal ?breakers?$"#) ?? lo.groups(#"^deal ?breakers?:?\s+(.+)$"#)
            ?? (noThanks ? nil : lo.groups(#"^(?:no|avoid|without|not near|not on|nothing (?:on|near|with)|(?:i )?don'?t want(?: to be (?:on|near))?(?: an?)?)\s+(.+)$"#))
        let nM = lo.groups(#"^(?:make )?(.+?) (?:is |are )?(?:just )?(?:a )?nice[- ]to[- ]haves?$"#)
        if let m = mM ?? dM ?? nM, let body = m[1] {
            let mode: CriterionMode = mM != nil ? .must : dM != nil ? .deal : .nice
            if !(mode != .nice && body.rx(special)) && !(mode == .deal && !feats.isEmpty) {
                let fs = mode == .must ? feats : []
                let cs = AskText.splitCriteria(AskText.stripFeatures(body))
                if !fs.isEmpty || cs.count > 1 {
                    return fast(applyAsk(s, feats: fs, crits: cs.map { normCrit($0, s, loose: cs.count == 1) }, mode: mode))
                }
                if cs.count == 1 && (mode != .deal || body.count > 2) {
                    return fast(setMode(s, normCrit(cs[0], s, loose: true), mode))
                }
            }
        }

        if lo.rx(#"\b(similar|more like|homes? like|houses? like|places? like|ones? like|like (this|that|it)( one)?)\b"#) && !lo.rx(#"\b(i|we|you) (would |really )?like\b"#) {
            guard let tgt else {
                return slow(["Comparing price, size and location", "Finding the closest matches"], N,
                            bot("Which home should I match? Tap an address in our chat or tell me the street, like “homes like " + (vis.first.map(street) ?? "that one") + "”.", surface: true, next: pruned(s)))
            }
            return slow(["Comparing price, size and location", "Finding the closest matches"], N, similar(tgt, s, pre: pre))
        }

        if lo.rx(#"\b(tour|tours|see (it|this|that|the (home|house|place)) in person|schedule (a )?(showing|viewing|visit)|book (a )?(showing|viewing|visit)|visit (it|this|that)|go see|walk ?through)\b"#) && !lo.rx(#"\b(virtual|3d|video) tour\b"#) {
            guard let x = tgt else {
                return fast(bot("Which home would you like to tour? Tell me the street, or pick one of these.", surface: true, next: pruned(s),
                                sugs: bestOf(vis, s).prefix(3).map { "Tour " + street($0.x) }))
            }
            lastHome = x.id
            return fast(bot("I can set up a tour of \(street(x)). Pick a day and time, and a Redfin agent will meet you there. Tours are free, with no obligation.",
                            surface: true, next: pruned(s), cta: AskCTA(label: "Schedule a tour", kind: .tour, listingID: x.id),
                            sugs: ["Can I afford it?", "Homes like this one", "Does it have a garage?"]))
        }

        if lo.rx(#"\b(can i afford|could i afford|afford (it|this|that|the)|affordability|monthly (payment|cost)s?|mortgage|pre-?approv\w*|down payment|interest rates?|(a|per) month for)\b|how much (would|will|is) (it|that|this)( be| cost)?( a| per) month"#) {
            return slow(["Estimating monthly costs"], N, afford(tgt, s))
        }

        if lo.rx(#"\b(talk|speak|chat) (to|with) (an? |my )?(agent|realtor|person|human|someone|somebody)\b|\b(redfin agent|real estate agent|realtor|buyer'?s agent|an agent)\b|\b(make|write|submit|put in) (an )?offers?\b|\bnext steps?\b|\bhow do i (buy|start|make an offer)\b|\bnegotiat\w*|\binspections?\b"#) {
            let area = tgt?.neighborhood ?? s.locations[0].replacingOccurrences(of: ", WA", with: "")
            return fast(bot("A Redfin agent is the best next step for that. \(Self.agentName) works with buyers in \(area) and can answer questions, tour homes with you and write offers. They’ll see your search and criteria, so you won’t have to start over.",
                            surface: true, next: pruned(s), cta: AskCTA(label: "Connect with \(Self.agentFirst)", kind: .agent, listingID: tgt?.id),
                            sugs: ["Which one fits me best?", "Can I afford the top match?"]))
        }

        if lo.rx(#"\bwhich (one|home|house|of (these|them|those))? ?(should|would|do) (i|you|we) (pick|choose|recommend|go with|buy|get)\b|\bwhich (one|home|house)? ?(fits|suits|matches) (me|us|best)\b|\b(fits|suits|matches) (me|us) best\b|\bbest (fit|match|home|one) for (me|us)\b|\bwhat('?s| is) (the|your) (top|best) (pick|match|fit|one)\b|\byour (top )?(pick|recommendation)\b|\brecommend (a|one|me)\b|\bwhich is (the )?best( one)?$"#) {
            return slow(["Weighing your criteria"], N, bestFit(vis, s, pre: pre))
        }

        let tti = HomeAnalyses.travelTargets.firstIndex { lo.rx($0.pattern) }
        let tmM = lo.groups(#"\b(\d{1,3})\s*-?\s*(?:min|mins|minutes?)\b"#)
        if let tti, tmM != nil || lo.rx(#"\b(drive|driving|commute|travel time|how long|walk(ing)? time|bik(e|ing)|transit time|by bus)\b"#) {
            let mode: HomeAnalyses.TravelMode = lo.rx(#"\bwalk"#) ? .walk : lo.rx(#"\bbik(e|ing)|cycl"#) ? .bike : lo.rx(#"\btransit|\bbus\b|light rail"#) ? .transit : .drive
            let name = HomeAnalyses.travelTargets[tti].place.name
            return slow(["Locating " + name, "Estimating \(mode.noun) times"], N, travel(tti, mode, Int(tmM?[1] ?? "") ?? 0, s, pre: pre))
        }

        if addrHit != nil || addrLike {
            guard let x = addrHit, vis.contains(x) else {
                return fast(bot(addrHit.map { street($0) + " is outside your current filters. Want me to loosen them so it shows up?" } ?? "That home isn’t in your current results. Want me to look it up?",
                                surface: true, next: pruned(s)))
            }
            let a = lo.rx(#"^(show|open|go to|take me|pull up|find)\b"#)
                ? "Here’s \(street(x)): \(x.formattedPrice), \(x.beds) bd, \(x.bathsFormatted) ba, \(sqftText(x)) sq ft."
                : propAnswer(x, lo, street(x))
            lastHome = x.id
            return fast(bot(a, next: pruned(s)))
        }
        let lastId = (s.highlighted.count == 1 ? s.highlighted.first : nil) ?? lastHome
        if let lastId, lo.rx(#"\b(it|its|that one|this one|that home|that house|that place)\b"#), lo.rx(#"\b(does|do|is|has|have|what|how|when|any)\b"#), let x = H(lastId) {
            return fast(bot(propAnswer(x, lo, "It"), next: pruned(s)))
        }

        if let r = rankOrOrdinal(lo, vis, s, pre: pre) { return r }
        if let r = streetQuery(t, lo, vis, s, feats: feats, pre: pre) { return r }

        if lo.rx(#"\bsh(or|ro)t[- ]?sales?\b"#) {
            if lo.rx(#"\b(avoid|no|exclude|hide|without|skip|remove|not|don'?t)\b"#) { return fast(setFeats(s, ["Exclude short sales"], tool: "Hid short sales")) }
            let xs = vis.filter { $0.facts?.isShortSale == true }
            guard !xs.isEmpty else {
                offer = expandOffer
                return slow(["Checking sale types", "Counting short sales"], N, bot(pre + (N == 1 ? "The 1 home in your results isn’t a short sale" : "None of the \(N) homes in your results are short sales") + ". Want me to widen your price range or add another area?", surface: true, next: pruned(s)))
            }
            return slow(["Checking sale types", "Counting short sales"], N,
                        bot(pre + (N == 1 ? "The 1 home in your results " : "\(xs.count) of the \(N) homes in your results ") + (xs.count == 1 ? "is a short sale" : "are short sales") + ": " + list(xs) + ". Short sales need lender approval, so closing often takes longer. Turn off “Short sales” to see the rest.",
                            tools: ["Showing only short sales"], next: addRef(s, id: "short", label: "Short sales", xs),
                            sugs: ["Which of those is the biggest?", "Hide the short sales", "Does the cheapest one have a garage?"]))
        }

        if lo.rx(#"\btransit\b|\bbus(es)?\b|light rail|(don'?t|do not) (have|own) a car|without a car|\bno car\b|get around"#) {
            if lo.rx(#"\b(sort|rank|order|colou?r|shade|map)\b"#) { return slow(["Pulling transit scores", "Ranking homes"], N, applyAnalysis("transit", s, scope: scope, pre: pre)) }
            let ok = vis.filter { $0.facts?.transitScore != nil }.sorted { ($0.facts?.transitScore ?? 0) > ($1.facts?.transitScore ?? 0) }
            let miss = vis.count - ok.count
            guard let x = ok.first else { return slow(["Pulling transit scores", "Comparing homes"], N, bot(pre + "None of the homes in your results list a transit score.", surface: true, next: pruned(s))) }
            let score = { (l: Listing) in String(l.facts?.transitScore ?? 0) }
            let text = pre + "\(street(x)) has the highest transit score, \(score(x))." + (ok.count > 1 ? " Next is \(street(ok[1])) at \(score(ok[1]))." : "") + (miss > 0 ? " \(miss)" + (miss == 1 ? " home doesn’t" : " homes don’t") + " list a score." : "")
            return slow(["Pulling transit scores", "Comparing homes"], N, bot(text, next: hi(s, [x.id], list: ok.map(\.id)), sugs: ["Sort by transit score", "Does it have a garage?", "Closest to Green Lake first"]))
        }

        if lo.rx(#"\b(good|great|excellent|fair|poor|bad|move[- ]in) (condition|shape)\b|\bneeds? (some )?work\b|\bfixer\b|\bturn[- ]?key\b|\bmove[- ]in ready\b"#) {
            let bad = lo.rx(#"fair|poor|bad|needs? (some )?work|fixer"#), cheap = lo.rx(#"\b(cheap|cheaper|less expensive|affordable|lower[- ]priced|budget)\b"#)
            let prices = vis.map(\.price).sorted()
            let med = prices.isEmpty ? 0 : prices[prices.count / 2]
            let xs = vis.filter { (bad ? ["Fair", "Needs work"] : ["Good", "Excellent"]).contains($0.facts?.condition ?? "") && (!cheap || $0.price < med) }
            let what = bad ? "need some work" : "are in good condition"
            let text = pre + (xs.isEmpty ? "None of the " + (cheap ? "lower-priced " : "") + "homes " + what + " based on their listings."
                : "\(xs.count)" + (cheap ? " of the lower-priced homes " : " homes ") + what + " based on their listings: " + list(xs) + "." + (cheap ? " I counted homes under \(SearchState.money(Int((Double(med) / 1000).rounded()) * 1000)) as lower priced." : ""))
            return slow(["Reading listing details", "Comparing condition"], N, bot(text, next: hi(s, xs.map(\.id), list: xs.map(\.id)), sugs: ["Which of those is the biggest?", "Does the cheapest one have a garage?", "Sort by price per sq ft"]))
        }

        if lo.rx(#"\b(average|avg|mean|median|typical)\b"#) { return slow(["Pulling listing data", "Calculating"], N, averages(lo, vis, s, pre: pre)) }

        // Analyses: groceries, schools, landmarks, parks, price per sq ft, colors.
        let anVerb = #"\b(colou?r|shade|analy[sz]e|heat\s?map|visuali[sz]e)\b"#
        let near = lo.rx(#"\b(close|closest|closer|near|nearest|nearby|distance|walk(ing|able)?|minutes?|proximity|commute)\b"#) || lo.rx(anVerb) || lo.rx(#"\b(sort|rank|order)\b"#)
        if lo.rx(#"grocer|supermarket|food store|trader joe|whole foods|\bpcc\b|\bqfc\b"#) {
            let multi = lo.rx(#"\b(bunch|lots|lot of|many|several|most|multiple|plenty|a few|options)\b"#)
            var r = applyAnalysis(multi ? "groceryN" : "grocery", s, scope: scope, pre: pre)
            r.suggestions = ["Which has the best transit score?", "Closest to Green Lake first", "Does the cheapest one have a garage?"]
            return slow(["Finding grocery stores nearby", multi ? "Counting stores within 1 mi" : "Measuring distances"], N, r)
        }
        if lo.rx(#"\bschools?\b"#) && near { return slow(["Finding schools nearby", "Measuring distances"], N, applyAnalysis("schools", s, scope: scope, pre: pre)) }
        if let lm = HomeAnalyses.landmarkPatterns.firstIndex(where: { lo.rx($0) }), near {
            return slow(["Locating " + HomeAnalyses.landmarks[lm].name, "Measuring distances"], N, applyAnalysis("to:\(lm)", s, scope: scope, pre: pre))
        }
        if lo.rx(#"\bparks?\b"#) && near { return slow(["Finding parks nearby", "Measuring distances"], N, applyAnalysis("parks", s, scope: scope, pre: pre)) }
        if lo.rx(#"(price|cost|\$)\s*(per|/|a)\s*(sq|square)|ppsf|per\s*(sq|square)"#, caseInsensitive: true) || (lo.rx(#"\bparks?\b"#) && lo.rx(anVerb)) {
            let key = lo.rx(#"\bparks?\b"#) ? "parks" : "ppsf"
            return slow(["Pulling listing data", "Ranking homes"], N, applyAnalysis(key, s, scope: scope, pre: pre))
        }

        if !feats.isEmpty {
            let cs = AskText.splitCriteria(AskText.stripFeatures(t)).map { normCrit($0, s, loose: false) }
            return fast(cs.isEmpty ? setFeats(s, feats, tool: nil) : applyAsk(s, feats: feats, crits: cs))
        }
        if let tyM = lo.groups(#"\b(condos?|town ?(?:houses?|homes?)|multi[- ]family|single[- ]family|houses)\b"#), let w = tyM[1], lo.rx(#"\b(only|just|show|find|see|want|looking for)\b"#) {
            let ty = w.contains("condo") ? "Condo" : w.contains("town") ? "Townhouse" : w.contains("multi") ? "Multi-family" : "House"
            var nx = pruned(s); nx.filters.types = [ty]
            let n = count(nx)
            return fast(bot(n > 0 ? "Showing \(AskText.homes(n))." : "No homes match that. Want me to loosen your filters?", surface: n == 0, tools: ["Set home type to \(ty.lowercased())"], next: nx))
        }
        if let hood = SearchRegions.shared.places.first(where: { $0.kind.hasPrefix("Neighborhood") && lo.rx(#"\b"# + AskText.esc($0.name.lowercased()) + #"\b"#) }) {
            var nx = pruned(s); nx.locations = [hood.name]
            return fast(bot("Searching in \(hood.name).", tools: ["Moved your search to \(hood.name)"], next: nx))
        }
        return fast(runBasic(t, s))
    }

    // MARK: - Areas

    private func inside(_ a: String, _ b: String) -> Bool {
        guard a != b, let p = SearchRegions.shared.polygons[a], let q = SearchRegions.shared.polygons[b] else { return false }
        return p.isInside(q)
    }

    private func planLoc(_ names: [String], _ cur: [String], replace: Bool) -> (next: [String], verb: String?) {
        if replace { return (names, cur.count == names.count && names.allSatisfy(cur.contains) ? nil : "Changed area to") }
        var next = cur, verb: String?
        for name in names where !next.contains(name) {
            let wider = next.filter { inside(name, $0) }, narrower = next.filter { inside($0, name) }
            next = next.filter { !wider.contains($0) && !narrower.contains($0) } + [name]
            verb = !wider.isEmpty || !narrower.isEmpty || verb == "Changed area to" ? "Changed area to" : "Added"
        }
        return (next, verb)
    }

    private func moveTo(_ s: SearchState, _ names: [String], replace: Bool, then: String?) -> AskReply {
        let p = planLoc(names, s.locations, replace: replace)
        if p.verb == nil, let then { return route(then, s) }
        guard let verb = p.verb else { return bot("You’re already searching \(AskText.joinAnd(p.next)).", surface: true) }
        var nx = pruned(s); nx.locations = p.next
        let tool = verb + " " + AskText.joinAnd(names)
        if let then {
            var r = route(then, nx)
            r.tools.insert(tool, at: 0)
            if r.next == nil { r.next = nx }
            if r.slow { r.workDone = "Checked \(AskText.homes(count(r.next ?? nx)))" }
            return r
        }
        let n = count(nx)
        return bot(n > 0 ? "Showing \(AskText.homes(n)) in \(AskText.joinAnd(p.next))." : "No homes in \(AskText.joinAnd(p.next)) match your filters. Want me to loosen them?",
                   surface: n == 0, tools: [tool], next: nx, sugs: ["Sort by transit score", "Which of these are short sales?", "Does the cheapest one have a garage?"])
    }

    private func expand(_ s: SearchState, then: String?) -> AskReply {
        guard let w = SearchRegions.shared.widerArea(than: s.locations) else {
            return bot("You’re already searching all of \(AskText.joinAnd(s.locations)). Want me to add Shoreline, Kirkland or Bellevue?", surface: true)
        }
        return moveTo(s, [w], replace: false, then: then)
    }

    // MARK: - Criteria and filters

    private func normCrit(_ p: String, _ s: SearchState, loose: Bool) -> String {
        var c = p.lowercased().replacingRx(#"^(a|an|the|any|some)\s+"#, with: "").replacingRx(#"[.!?]+$"#, with: "").trimmingCharacters(in: .whitespaces)
        var ws = c.split(separator: " ").map(String.init)
        if let lw = ws.last, lw.count > 4, lw.rx(#"[^s]s$"#) { ws[ws.count - 1] = String(lw.dropLast()) }
        c = ws.joined(separator: " ")
        let sg = { (k: String) in k.hasSuffix("s") ? String(k.dropLast()) : k }
        return s.criteria.first { $0 == c || sg($0) == sg(c) } ?? (loose ? s.criteria.first { $0.contains(c) || c.contains($0) } : nil) ?? c
    }

    private func applyAsk(_ s0: SearchState, patch: AskText.Patch = .init(), expose: [String] = [], feats: [String] = [], crits csIn: [String] = [], mode: CriterionMode = .nice) -> AskReply {
        var cs: [String] = []
        for c in csIn where !cs.contains(c) { cs.append(c) }
        var keys: [String] = []
        if patch.touchesPrice { keys.append("price") }
        if patch.touchesRooms { keys.append("rooms") }
        var nx = pruned(s0)
        for c in cs {
            if !nx.criteria.contains(c) { nx.criteria.append(c) }
            if mode == .nice { if !s0.criteria.contains(c) { nx.modes[c] = nil } } else { nx.modes[c] = mode }
        }
        if let v = patch.minPrice { nx.filters.minPrice = v }
        if let v = patch.maxPrice { nx.filters.maxPrice = v }
        if let v = patch.beds { nx.filters.beds = v }
        if let v = patch.baths { nx.filters.baths = v }
        for f in feats where !nx.filters.features.contains(f) { nx.filters.features.append(f) }
        for k in keys + expose where !nx.exposed.contains(k) { nx.exposed.append(k) }

        let n = count(nx)
        let q = { (c: String) in "“\(c)”" }
        let added = cs.filter { !s0.criteria.contains($0) }, remade = mode == .nice ? [] : cs.filter { s0.criteria.contains($0) }
        var tools: [String] = []
        if keys.contains("price") {
            tools.append(nx.priceLabel.map { "Set price to " + $0.prefix(1).lowercased() + $0.dropFirst() } ?? "Removed your price limit")
        }
        if keys.contains("rooms") {
            let r = [nx.filters.beds > 0 ? "\(nx.filters.beds)+ beds" : nil, nx.filters.baths > 0 ? "\(num(nx.filters.baths))+ baths" : nil].compactMap { $0 }
            tools.append(r.isEmpty ? "Cleared beds and baths" : "Set " + AskText.joinAnd(r))
        }
        for k in expose { tools.append("Showing the " + (k == "rooms" ? "Beds & baths" : "Price") + " filter" + (k == "price" ? " for price" : "")) }
        if !feats.isEmpty { tools.append("Filtered to homes with " + AskText.joinAnd(feats.map { AskText.featureText[$0] ?? $0.lowercased() })) }
        if !added.isEmpty { tools.append("Added " + AskText.joinAnd(added.map(q)) + (mode == .must ? (added.count > 1 ? " as must-haves" : " as a must-have") : mode == .deal ? (added.count > 1 ? " as dealbreakers" : " as a dealbreaker") : "")) }
        if !remade.isEmpty { tools.append("Made " + AskText.joinAnd(remade.map(q)) + (mode == .must ? " must-haves" : " dealbreakers")) }
        let onlyExpose = !expose.isEmpty && keys.isEmpty && feats.isEmpty && cs.isEmpty
        let text: String
        if onlyExpose {
            text = expose[0] == "rooms" ? "Pick a minimum in the Beds & baths filter, or just tell me, like “3 beds and 2 baths”." : "Set a range in the Price filter, or just tell me, like “under $1.2M”."
        } else if n == 0 {
            text = "No homes match that. Want me to loosen your filters?"
        } else if !cs.isEmpty && mode == .must {
            text = "Showing only the \(AskText.homes(n)) that mention \(AskText.joinAnd(cs))."
        } else if !cs.isEmpty && mode == .deal {
            text = "Hiding homes that mention \(AskText.joinAnd(cs)). Showing \(AskText.homes(n))."
        } else if !added.isEmpty {
            text = "Showing \(AskText.homes(n)), ranked by \(AskText.ranked(nx.scoringCriteria.count))."
        } else {
            text = "Showing \(AskText.homes(n))."
        }
        return bot(text, surface: onlyExpose || n == 0, tools: tools, next: nx)
    }

    private func setMode(_ s0: SearchState, _ c: String, _ mode: CriterionMode) -> AskReply {
        let isNew = !s0.criteria.contains(c)
        var nx = pruned(s0)
        if !nx.criteria.contains(c) { nx.criteria.append(c) }
        nx.modes[c] = mode == .nice ? nil : mode
        let n = count(nx)
        let tool = isNew
            ? (mode == .must ? "Added “\(c)” as a must-have" : mode == .deal ? "Added “\(c)” as a dealbreaker" : "Added “\(c)”")
            : (mode == .must ? "Made “\(c)” a must-have" : mode == .deal ? "Made “\(c)” a dealbreaker" : "Made “\(c)” a nice-to-have")
        let text: String
        if n == 0 {
            text = "None of the homes in your results " + (mode == .deal ? "are free of " + c : "mention " + c) + ". Want me to make it a nice-to-have instead?"
            offer = { [weak self] st in self?.fast(self?.setMode(st, c, .nice) ?? AskReply(bot: "")) ?? AskReply(bot: "") }
        } else if mode == .must {
            text = "Showing only the \(AskText.homes(n)) that mention \(c). Homes without it are hidden."
        } else if mode == .deal {
            text = "Hiding homes that mention \(c). Showing \(AskText.homes(n))."
        } else {
            text = isNew ? "Re-ranked by \(AskText.ranked(nx.scoringCriteria.count))." : "“\(c.capitalizedFirst)” now counts toward each home’s match score instead of hiding homes. Showing \(AskText.homes(n))."
        }
        return bot(text, surface: n == 0, tools: [tool], next: nx)
    }

    private func setFeats(_ s: SearchState, _ list: [String], tool: String?) -> AskReply {
        var nx = pruned(s)
        for f in list where !nx.filters.features.contains(f) { nx.filters.features.append(f) }
        if list.contains("Exclude short sales") { nx.refinements.removeAll { $0.id == "short" } }
        let n = count(nx)
        let stairs = query.rx(#"stairs|single[- ]level|one[- ]level"#)
        let t = tool ?? "Filtered to homes with " + AskText.joinAnd(list.map { AskText.featureText[$0] ?? $0.lowercased() })
        return n > 0
            ? bot((stairs ? "I added a filter for homes with the primary bedroom on the main floor. " : "") + "Showing \(AskText.homes(n)).", surface: stairs, tools: [t], next: nx)
            : bot("No homes match that. Want me to loosen your filters?", surface: true, tools: [t], next: nx)
    }

    private func freshStart(_ s: SearchState, full: Bool) -> AskReply {
        lastHome = nil
        var nx = s
        nx.clearSearch()
        if full { nx.tours = []; nx.watches = [] }
        var r = bot(full ? "Started fresh. I cleared your criteria, filters, saved homes and tours. Tell me what you want in a home, in your own words."
                         : "Started a new search. I cleared your area, filters and criteria, and kept your saved homes and tours. Tell me what you want in a home, in your own words.",
                    tools: [full ? "Cleared your search and memory" : "Cleared your search"], next: nx,
                    sugs: ["Natural light", "Under $900K", "Within a 20 min drive of South Lake Union"])
        r.action = .freshStart(full: full)
        lastList = []
        return r
    }

    // MARK: - Questions

    private func propAnswer(_ x: Listing, _ lo: String, _ subj: String, optional: Bool = false) -> String {
        let S = subj
        func F(_ ft: String, _ yes: String, _ no: String) -> String {
            HomeCatalog.hasFeature(x, ft) ? "\(S) \(yes)." : "The listing doesn’t mention \(no). A tour or a Redfin agent can confirm."
        }
        let f = x.facts
        if lo.rx(#"garage|parking|park (my|the|a) car"#) {
            let n = f?.garageCars ?? 0
            return n > 0 ? "\(S) has a \(n)-car garage." : "The listing doesn’t mention a garage or parking. A tour or a Redfin agent can confirm."
        }
        if lo.rx(#"\bbasements?\b"#) {
            let b = f?.basementSqft ?? 0
            return b > 0 ? "\(S) has " + (f?.basementFinished == true ? "a finished" : "an unfinished") + " basement, about \(sqf(Double(b)))." : "\(S) doesn’t list a basement. A tour or a Redfin agent can confirm."
        }
        if lo.rx(#"\b(lot|yard|backyard|land)\b"#) && !lo.rx(#"\b(large|big|fenced|nice|private) (yard|backyard)\b"#) {
            if let l = f?.lotSqft { return "\(S) sits on a \(sqf(Double(l))) lot." }
            return "\(S) doesn’t list a lot size" + (x.propertyType == "Condo" ? ", since it’s a condo" : "") + "."
        }
        if lo.rx("fireplace") { return F("Fireplace", "has a fireplace", "a fireplace") }
        if lo.rx(#"\b(a/?c|air[- ]?condition\w*|cooling)\b"#) { return F("Air conditioning", "has air conditioning", "air conditioning") }
        if lo.rx("washer|dryer|laundry") { return F("Washer/dryer", "has a washer and dryer", "a washer or dryer") }
        if lo.rx(#"\bpool\b"#) { return F("Pool", "has a pool", "a pool") }
        if lo.rx("waterfront|on the water") { return F("Waterfront", "is waterfront", "waterfront access") }
        if lo.rx(AskText.mainBedPattern) {
            return HomeCatalog.hasFeature(x, "Primary bed on main") ? "\(S) has the primary bedroom on the main floor." : "\(S) doesn’t have the primary bedroom on the main floor."
        }
        if lo.rx(#"\bhoa\b"#) { let h = HomeCatalog.hoa(x); return h > 0 ? "The HOA is $\(h) a month." : "\(S) doesn’t list an HOA." }
        if lo.rx(#"transit|\bbus\b|light rail"#) { return f?.transitScore.map { "\(S) has a transit score of \($0)." } ?? "\(S) doesn’t list a transit score." }
        if lo.rx("condition|shape|updated|renovat") { return "Its listing describes it as in \((f?.condition ?? "good").lowercased()) condition." }
        if lo.rx(#"sh(or|ro)t[- ]?sale"#) { return f?.isShortSale == true ? "\(S) is a short sale." : "\(S) isn’t a short sale." }
        if lo.rx(#"\b(on (the )?market|days on|how long (has|have|been)|when (was|did) (it|they) (list|hit))\b|\blisted\b"#) {
            let d = x.daysOnMarket
            return "\(S) has been on Redfin for " + (d == 1 ? "1 day" : "\(d) days") + "."
        }
        if lo.rx(#"\bper (sq|square)|\bppsf\b"#) { return "\(S) is $\(Int((Double(x.price) / Double(max(x.sqft, 1))).rounded()).formatted()) per sq ft." }
        if lo.rx(#"\b(how much|price|cost|asking)\b"#) && !lo.rx("month|afford|mortgage|payment|down|hoa|tax") { return "\(S) is listed at \(x.formattedFullPrice)." }
        if lo.rx(#"\bbuilt\b|\byear\b|how old"#) { return "\(S) was built in \(x.yearBuilt)." }
        if lo.rx(#"how (big|large)|square|sq ?ft|\bsize\b"#) { return "\(S) is \(sqftText(x)) sq ft." }
        if lo.rx(#"\bbath(room)?s?\b"#) && !lo.rx(#"\bbed"#) { return "\(S) has \(x.bathsFormatted)" + (x.bathsFormatted == "1" ? " bathroom." : " bathrooms.") }
        if lo.rx(#"\bbed(room)?s?\b"#) { return "\(S) has \(x.beds) bedrooms and \(x.bathsFormatted) baths." }
        if let c = HomeCatalog.knownCriteria.first(where: { lo.contains($0.split(separator: " ").last.map(String.init) ?? $0) }), lo.rx(#"\b(have|has|is there|got)\b"#) {
            return HomeCatalog.has(x, c) ? "The listing mentions \(Self.phrase[c] ?? c)." : "The listing doesn’t mention \(c). A tour or a Redfin agent can confirm."
        }
        if let m = lo.groups(#"\b(?:have|has|got)\s+(?:an?|any)\s+([a-z][a-z -]{2,24}?)\s*$"#), let w = m[1] {
            return "The listing doesn’t mention " + (w.rx("^[aeiou]") ? "an " : "a ") + w.trimmingCharacters(in: .whitespaces) + ". A tour or a Redfin agent can confirm."
        }
        return optional ? "" : "\(S) is \(x.formattedPrice), with \(x.beds) bd, \(x.bathsFormatted) ba and \(sqftText(x)) sq ft."
    }

    private func afford(_ x: Listing?, _ s: SearchState) -> AskReply {
        let price = x?.price ?? s.filters.maxPrice, hoa = x.map(HomeCatalog.hoa) ?? 0
        let sugs = x.map { ["Tour " + street($0), "Homes like this one", "Which one fits me best?"] } ?? ["Can I afford the top match?", "Which one fits me best?"]
        guard price > 0 else { return bot("Which home should I price out? Tell me the street, or set a top price and I’ll estimate a monthly payment.", surface: true, next: pruned(s), sugs: sugs) }
        let e = Self.payment(price: price, hoa: hoa)
        let lead = x.map { "All in, \(street($0)) would be about \(cents(e.total)) a month" } ?? "At your top price of \(SearchState.money(price)), you’d pay about \(cents(e.total)) a month"
        if let x { lastHome = x.id }
        return bot(lead + ": \(cents(e.pi)) principal and interest and \(cents(e.ti)) taxes and insurance" + (hoa > 0 ? ", plus a \(cents(Double(hoa))) HOA" : "") + ". That assumes 20% down and a \(Self.rateText) rate. For a real number, Rocket Mortgage can pre-approve you, and I’ll keep your search right here.",
                   surface: true, next: pruned(s), cta: AskCTA(label: "Get pre-approved with Rocket", kind: .rocket, listingID: x?.id, price: price), sugs: sugs)
    }

    /// 80% loan at 6.5% over 30 years, plus 0.92% tax and 0.35% insurance a year.
    static func payment(price: Int, hoa: Int) -> (pi: Double, ti: Double, total: Double, down: Double) {
        let p = Double(price), loan = p * 0.8, r = rate / 12
        let pi = loan * r / (1 - pow(1 + r, -360)), ti = p * (0.0092 + 0.0035) / 12
        return (pi, ti, pi + ti + Double(hoa), p * 0.2)
    }

    private func bestFit(_ vis: [Listing], _ s: SearchState, pre: String) -> AskReply {
        let sc = scoring(s)
        guard !sc.isEmpty else { return bot("Tell me what matters most to you, like a big yard or a quiet street, and I’ll tell you which home fits best.", surface: true, next: pruned(s)) }
        guard !vis.isEmpty else {
            offer = expandOffer
            return bot("There aren’t any homes in your results to pick from. Want me to expand your search area?", surface: true, next: pruned(s))
        }
        let r = bestOf(vis, s), top = r[0], x = top.x, k = top.ok.count, nC = sc.count
        let miss = sc.filter { !HomeCatalog.has(x, $0) }, ties = r.filter { $0.ok.count == k }.count
        let m = nC == 1 ? (k > 0 ? "your criterion, " + top.ok[0] : "none of your criteria")
            : k == nC ? "all \(nC) of your criteria: " + AskText.joinAnd(top.ok)
            : k > 0 ? "\(k) of your \(nC) criteria: " + AskText.joinAnd(top.ok) : "none of your criteria"
        lastHome = x.id
        let text = pre + "Based on what you’ve told me, \(street(x)) fits best. It matches \(m)."
            + (!miss.isEmpty && k > 0 ? " Its listing doesn’t mention \(AskText.joinAnd(miss)), so that’s worth checking on a tour." : "")
            + (ties > 1 ? " \(ties - 1)" + (ties == 2 ? " other home matches" : " other homes match") + " as many, and I picked " + (favorites().contains(x.id) ? "the one you saved" : "the first in your list") + "." : "")
            + " I’m not weighing price here. A Redfin agent can compare it with recent nearby sales."
        var nx = pruned(s); nx.highlighted = [x.id]
        return bot(text, next: nx, cta: AskCTA(label: "Schedule a tour", kind: .tour, listingID: x.id), sugs: ["Can I afford it?", "Homes like this one", "Does it have a garage?"])
    }

    private func similar(_ x0: Listing, _ s: SearchState, pre: String) -> AskReply {
        let p0 = Double(x0.price), s0 = Double(max(x0.sqft, 1)), b0 = Double(x0.beds), ba0 = x0.baths, t0 = x0.propertyType
        var refless = s; refless.refinements = []
        let xs = pool(s).filter { $0.id != x0.id && SearchEngine.passes($0, s.filters) && SearchEngine.refinementsAllow($0, refless) }
            .map { x -> (Listing, Double) in
                let d = abs(log(Double(x.price) / p0)) * 3 + abs(Double(x.beds) - b0) * 0.6 + abs(x.baths - ba0) * 0.4
                    + abs(log(Double(x.sqft > 0 ? x.sqft : Int(s0)) / s0)) * 2 + (x.propertyType == t0 ? 0 : 1)
                    + TravelTime.miles(x.latitude, x.longitude, x0.latitude, x0.longitude) * 0.5
                return (x, d)
            }
            .sorted { $0.1 < $1.1 }.prefix(8).map(\.0)
        guard !xs.isEmpty else { return bot("I couldn’t find homes like \(street(x0)) with your current filters. Want me to loosen them?", surface: true, next: pruned(s)) }
        let lbl = "Like " + street(x0)
        var nx = pruned(s)
        nx.refinements = [SearchRefinement(id: "like:" + x0.id, label: lbl, listingIDs: xs.map(\.id))]
        lastList = xs.map(\.id)
        let closest = xs.count > 1 ? "are \(street(xs[0])) (\(xs[0].formattedPrice)) and \(street(xs[1])) (\(xs[1].formattedPrice))" : "is \(street(xs[0])) (\(xs[0].formattedPrice))"
        return bot(pre + "Here are the \(AskText.homes(xs.count)) most like \(street(x0)) (\(x0.formattedPrice), \(x0.beds) bd, \(sqftText(x0)) sq ft, \(t0.lowercased())). I compared price, size, beds and baths, home type and location. The closest \(closest). Turn off “\(lbl)” to see the rest.",
                   tools: ["Showing \(AskText.homes(xs.count)) like \(street(x0))"], next: nx, sugs: ["Which one fits me best?", "Can I afford the first one?", "Sort by distance to parks"])
    }

    private func travel(_ ti: Int, _ mode: HomeAnalyses.TravelMode, _ lim: Int, _ s: SearchState, pre: String) -> AskReply {
        let T = HomeAnalyses.travelTargets[ti].place, name = T.name.replacingOccurrences(of: "^the ", with: "", options: .regularExpression)
        let vis = visible(s), N = vis.count
        guard N > 0 else {
            offer = expandOffer
            return bot("There aren’t any homes to check with your current filters. Want me to expand your search area?", surface: true, next: pruned(s))
        }
        let rows = vis.map { ($0, HomeAnalyses.travelMinutes($0, T, mode)) }.sorted { $0.1 < $1.1 }
        let v0 = rows[0].1, v1 = rows[rows.count - 1].1
        let within = lim > 0 ? rows.filter { $0.1 <= lim }.map(\.0) : []
        let lbl = "Within \(lim) min of \(name)", useRef = lim > 0 && !within.isEmpty && within.count < N
        let best = "\(street(rows[0].0)) is quickest, \(rows[0].1) min \(mode.noun) to \(name)."
        var text = pre + "Estimated \(mode.noun) times to \(T.name) run from \(v0) to \(v1) min\(mode.params.note). "
        if lim > 0 {
            text += within.isEmpty ? "None are within \(lim) minutes. " + best
                : within.count == N ? "All \(AskText.homes(N)) are within \(lim) minutes."
                : "\(within.count) of the \(N) homes in your results are within \(lim) minutes. Turn off “\(lbl)” to see the rest."
        } else { text += best }
        var nx = pruned(s)
        nx.analysis = SearchAnalysis(key: "tt:\(ti):\(mode.rawValue)")
        nx.sort = .analysis
        nx.refinements.removeAll { $0.id == "tt" }
        if useRef { nx.refinements.append(SearchRefinement(id: "tt", label: lbl, listingIDs: within.map(\.id))) }
        lastList = (useRef ? within : rows.map(\.0)).map(\.id)
        return bot(text, tools: ["Colored and sorted by \(mode.noun) time to \(name)"], next: nx, sugs: ["Which one fits me best?", "Homes like the first one", "Which has the best transit score?"])
    }

    private func applyAnalysis(_ key: String, _ s: SearchState, scope: String, pre: String) -> AskReply {
        guard let A = HomeAnalyses.lookup(key) else { return bot("I can’t analyze that yet.", surface: true) }
        let rows = visible(s).map { ($0, A.value($0)) }
        let ok = rows.compactMap { r in r.1.map { (r.0, $0) } }.sorted { $0.1 < $1.1 }
        let miss = rows.count - ok.count
        var nx = pruned(s)
        nx.analysis = SearchAnalysis(key: key)
        nx.sort = .analysis
        lastList = ok.map(\.0.id)
        guard let first = ok.first, let last = ok.last else {
            offer = expandOffer
            return bot("There aren’t any homes to analyze with your current filters. Want me to expand your search area?", surface: true,
                       tools: ["Colored and sorted by " + A.title.prefix(1).lowercased() + A.title.dropFirst()], next: nx)
        }
        let label = A.label(first.0)
        let best: String
        switch key {
        case "ppsf": best = "\(street(first.0)) is lowest at \(label)."
        case "transit": best = "\(street(first.0)) has the highest, \(first.0.facts?.transitScore ?? 0)."
        case "groceryN": best = "\(street(first.0)) has the most, \(label)."
        default: best = "\(street(first.0)) is closest, \(label)."
        }
        let missing = key == "transit" ? "a transit score" : "a value"
        let text = pre + "Ranges from \(A.format(first.1)) to \(A.format(last.1)). " + best
            + (miss > 0 ? " \(miss)" + (miss == 1 ? " home doesn’t" : " homes don’t") + " list \(missing)." : "")
            + (pre.isEmpty && !scope.isEmpty ? " " + scope : "")
        return bot(text, tools: ["Colored and sorted by " + A.title.prefix(1).lowercased() + A.title.dropFirst()], next: nx)
    }

    private func averages(_ lo: String, _ vis: [Listing], _ s: SearchState, pre: String) -> AskReply {
        let ty: String? = lo.rx("condo") ? "Condo" : lo.rx("town ?(house|home)") ? "Townhouse" : lo.rx("multi[- ]family|duplex") ? "Multi-family" : lo.rx(#"\bhouses?\b|single[- ]family"#) ? "House" : nil
        let tyL = ty.map { ["Condo": "condos", "Townhouse": "townhouses", "Multi-family": "multi-family homes", "House": "houses"][$0]! } ?? "homes"
        let set = ty.map { t in vis.filter { $0.propertyType == t } } ?? vis
        let md = lo.rx("median"), word = md ? "median" : "average"
        func agg(_ a: [Double]) -> Double {
            guard !a.isEmpty else { return 0 }
            if md { return a.sorted()[a.count / 2] }
            return a.reduce(0, +) / Double(a.count)
        }
        guard !set.isEmpty else { return bot(pre + "There aren’t any \(tyL) in your results.", surface: true, next: pruned(s)) }
        let one = set.count == 1 ? tyL.replacingRx("s$", with: "").replacingRx("homes$", with: "home") : tyL
        let none = { (m: Int, what: String) -> String in m > 0 ? " \(m)" + (m == 1 ? " doesn’t" : " don’t") + " list \(what)." : "" }
        let text: String
        if lo.rx(#"\bhoa\b|dues|\bfees?\b"#) {
            let w = set.filter { HomeCatalog.hoa($0) > 0 }, m = set.count - w.count
            text = w.isEmpty ? "None of the \(set.count) \(tyL) list an HOA."
                : "The \(word) HOA for the \(w.count) \(w.count == 1 ? one : tyL) with an HOA posted is $\(Int(agg(w.map { Double(HomeCatalog.hoa($0)) }).rounded())) a month." + (m > 0 ? " \(m)" + (m == 1 ? " doesn’t list one, so it’s" : " don’t list one, so they’re") + " left out." : "")
        } else if lo.rx(#"per (sq|square)|/ ?sq|ppsf"#) {
            text = "The \(word) price per sq ft for the \(set.count) \(one) is $\(Int(agg(set.map { Double($0.price) / Double(max($0.sqft, 1)) }).rounded()))."
        } else if lo.rx(#"\bbasements?\b"#) {
            let w = set.filter { ($0.facts?.basementSqft ?? 0) > 0 }
            text = w.isEmpty ? "None of the \(set.count) \(tyL) list a basement."
                : "The \(word) basement for the \(w.count) \(w.count == 1 ? one : tyL) with one is \(Int(agg(w.map { Double($0.facts?.basementSqft ?? 0) }).rounded()).formatted()) sq ft." + none(set.count - w.count, "a basement")
        } else if lo.rx(#"\b(lot|yard|land)\b"#) {
            let w = set.filter { $0.facts?.lotSqft != nil }
            text = w.isEmpty ? "None of the \(set.count) \(tyL) list a lot size."
                : "The \(word) lot size for the \(w.count) \(w.count == 1 ? one : tyL) with one listed is \(Int(agg(w.map { Double($0.facts?.lotSqft ?? 0) }).rounded()).formatted()) sq ft." + none(set.count - w.count, "a lot size")
        } else if lo.rx(#"\bbuilt\b|\byear\b"#) {
            text = "The \(word) year built for the \(set.count) \(one) is \(Int(agg(set.map { Double($0.yearBuilt) }).rounded()))."
        } else if lo.rx(#"sq ?ft|square|\bsize\b|\bbig\b"#) {
            text = "The \(word) size for the \(set.count) \(one) is \(Int(agg(set.map { Double($0.sqft) }).rounded()).formatted()) sq ft."
        } else if lo.rx(#"\bdays\b|on (the )?market|on redfin|how long"#) {
            text = "The \(word) time on Redfin for the \(set.count) \(one) is \(Int(agg(set.map { Double($0.daysOnMarket) }).rounded())) days."
        } else if lo.rx("transit") {
            let w = set.filter { $0.facts?.transitScore != nil }
            text = "The \(word) transit score for the \(w.count) \(tyL) with a score is \(Int(agg(w.map { Double($0.facts?.transitScore ?? 0) }).rounded()))." + none(set.count - w.count, "one")
        } else if lo.rx(#"\bbed"#) {
            text = "The \(word) number of bedrooms for the \(set.count) \(one) is \(String(format: "%.1f", agg(set.map { Double($0.beds) })))."
        } else {
            text = "The \(word) price for the \(set.count) \(one) is \(SearchState.money(Int((agg(set.map { Double($0.price) }) / 1000).rounded()) * 1000))."
        }
        return bot(pre + text, next: pruned(s), sugs: ["Color pins by price per sq ft", "Which of these are short sales?", "Does the cheapest one have a garage?"])
    }

    private func rankOrOrdinal(_ lo: String, _ vis: [Listing], _ s: SearchState, pre: String) -> AskReply? {
        let ranks: [(String, String, (Listing, Listing) -> Bool)] = [
            (#"\b(cheapest|least expensive|lowest[- ]priced|most affordable)\b"#, "The cheapest", { $0.price < $1.price }),
            (#"\b(most expensive|priciest|highest[- ]priced)\b"#, "The most expensive", { $0.price > $1.price }),
            (#"\b(biggest|largest|most space)\b"#, "The biggest", { $0.sqft > $1.sqft }),
            (#"\bsmallest\b"#, "The smallest", { $0.sqft < $1.sqft }),
            (#"\bnewest\b"#, "The newest", { $0.yearBuilt > $1.yearBuilt }),
            (#"\boldest\b"#, "The oldest", { $0.yearBuilt < $1.yearBuilt }),
        ]
        let ords: [(String, Int)] = [(#"\b(first|1st|number one)\b|#\s?1\b"#, 0), (#"\b(second|2nd|number two)\b|#\s?2\b"#, 1),
                                     (#"\b(third|3rd|number three)\b|#\s?3\b"#, 2), (#"\b(fourth|4th)\b|#\s?4\b"#, 3), (#"\blast one\b"#, -1)]
        let rk = ranks.first { lo.rx($0.0) }, od = ords.first { lo.rx($0.0) }
        guard rk != nil || od != nil, lo.rx(#"\b(one|home|house|place|listing|of (those|them|these))\b|#"#) || (rk != nil && lo.rx(#"^(which|what|who|what's|whats)\b"#)) else { return nil }
        let N = vis.count
        let refBack = lo.rx(#"\b(of (those|them|these)|on that street|that list)\b"#)
        let prior = lastList.compactMap(H).filter(vis.contains)
        let useList = (refBack || (od != nil && rk == nil)) && !prior.isEmpty
        let src = useList ? prior : vis
        var x: Listing?, lead = ""
        if let rk {
            x = src.sorted(by: rk.2).first
            if let x { lead = "\(rk.1) is \(street(x)) at \(x.formattedPrice)." }
        } else if let od {
            let i = od.1 < 0 ? src.count - 1 : od.1
            x = src.indices.contains(i) ? src[i] : nil
            if let x { lead = (useList ? "Number \(i + 1) on my list" : "The " + (["first", "second", "third", "fourth"].indices.contains(i) ? ["first", "second", "third", "fourth"][i] : "last") + " home in your results") + " is \(street(x)), \(x.formattedPrice)." }
        }
        let steps = [rk != nil ? "Sorting your results" : "Finding that home", "Checking its listing"]
        guard let x else {
            return slow(steps, N, bot("There " + (src.count == 1 ? "is only 1 home" : "are only \(src.count) homes") + " to pick from. Want me to widen your search?", surface: true, next: pruned(s)))
        }
        let q = propAnswer(x, lo, "It", optional: true)
        return slow(steps, N, bot(pre + lead + (q.isEmpty ? "" : " " + q) + (useList ? " From the \(AskText.homes(src.count)) I listed." : ""),
                                 next: hi(s, [x.id]), sugs: ["Does it have a fireplace?", "Which has the best transit score?", "Sort by distance to parks"]))
    }

    private func streetQuery(_ t: String, _ lo: String, _ vis: [Listing], _ s: SearchState, feats: [String], pre: String) -> AskReply? {
        var roads: [String] = []
        for l in pool(s) { let r = AskText.road(of: l); if !roads.contains(r) { roads.append(r) } }
        let toks = lo.replacingRx("[^a-z0-9 ]", with: " ").split(separator: " ").map(String.init)
        let cue = lo.rx(#"\b(on|along|down|off)\s+[a-z0-9]"#) || lo.rx(#"\b(st|street|ave|avenue|blvd|way|rd|road|dr|drive)\b"#)
        var road: String?, fuzzy = false
        if cue {
            for r in roads {
                let c = AskText.core(of: r)
                if c == "main" && !lo.rx("main (st|street)") { continue }
                if toks.contains(c) { road = r; fuzzy = false; break }
                if road == nil && c.count > 4 && toks.contains(where: { $0.count > 4 && AskText.levenshtein($0, c) <= 2 }) { road = r; fuzzy = true }
            }
        }
        let unknown = road == nil ? t.groups(#"\b(?:on|along|down)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)\s+(?:[Ss]t|[Ss]treet|[Aa]ve|[Aa]venue|[Bb]lvd|[Ww]ay|[Rr]d|[Rr]oad|[Dd]r|[Dd]rive|[Pp]l|[Pp]lace)\b"#) : nil
        guard road != nil || unknown != nil else { return nil }
        let N = vis.count, steps = ["Matching street names", "Checking each home"]
        guard let road else {
            offer = expandOffer
            let what = "on " + (unknown?[0] ?? "").replacingRx(#"^(on|along|down)\s+"#, with: "", caseInsensitive: true)
            return slow(steps, N, bot(pre + noneOf(N, what) + ". Want me to expand your search area?", surface: true, next: pruned(s)))
        }
        let ft = feats.filter { $0 != "Exclude short sales" }
        let xs = vis.filter { l in AskText.road(of: l) == road && ft.allSatisfy { f in HomeCatalog.hasFeature(l, f) } }
        let tag = ft.isEmpty ? "" : " with " + AskText.joinAnd(ft.map { AskText.featureText[$0] ?? $0 })
        let note = fuzzy ? " I read that as \(road)." : ""
        guard !xs.isEmpty else {
            offer = expandOffer
            return slow(steps, N, bot(pre + noneOf(N, "on " + road + tag) + "." + note + " Want me to expand your search area?", surface: true, next: pruned(s)))
        }
        let lead = N == 1 ? "The 1 home in your results " : "\(xs.count) of the \(N) homes in your results "
        return slow(steps, N, bot(pre + lead + (xs.count == 1 ? "is" : "are") + " on \(road)\(tag): \(list(xs)).\(note) Turn off “On \(road)” to see the rest.",
                                 surface: fuzzy, tools: ["Showing only homes on \(road)\(tag)"],
                                 next: addRef(s, id: "st:" + road + tag, label: "On " + road + (ft.isEmpty ? "" : " + \(ft.count)"), xs),
                                 sugs: ["Which of those is the biggest?", "Does the cheapest one have a garage?", "Sort by distance to parks"]))
    }

    private func runBasic(_ t: String, _ s: SearchState) -> AskReply {
        let ask = AskText.parseAsk(t, s.filters)
        if t.rx(#"\b(colou?r|shade|analy[sz]e|heat\s?map|visuali[sz]e)\b"#, caseInsensitive: true) && t.rx(#"\b(pins?|map|homes|results)\b"#, caseInsensitive: true) {
            return bot("I can color pins by distance to parks, grocery stores, schools or a place like Green Lake, by price per sq ft or by transit score.")
        }
        if !ask.patch.isEmpty { return applyAsk(s, patch: ask.patch) }
        // A question we can't answer gets an honest reply, never a junk criterion.
        let lq = t.lowercased().replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: .whitespaces)
        if lq.rx(AskText.questionPattern) || lq.rx(#"\?\s*$"#) {
            let vis = visible(s), N = vis.count
            let rankQ = lq.rx(#"\b(most|biggest|largest|highest|best|least|smallest|lowest|fewest|worst|better|bigger)\b"#)
            let alias: [String: String] = ["natural light": #"\b(sun|day)?light\b|\bsunny\b|\bbright\b"#, "finished basement": #"\bbasement\b"#,
                                           "large yard": #"\b(back)?yard\b"#, "home office": #"\boffice\b|work from home|\bwfh\b"#, "quiet street": #"\bquiet\b|\bnois(e|y)\b|\bloud\b"#]
            if let kc = HomeCatalog.knownCriteria.first(where: { lq.contains($0) || lq.rx(alias[$0] ?? "$^") }), N > 0 {
                let xs = vis.filter { HomeCatalog.has($0, kc) }
                let shown = xs.prefix(4).map { "\(street($0)) (\($0.formattedPrice))" }
                let known = s.criteria.contains(kc)
                var text = xs.isEmpty ? "None of the \(N) homes in your results mention \(kc)."
                    : "\(xs.count) of the \(N) homes in your results mention \(Self.phrase[kc] ?? kc): " + shown.joined(separator: ", ") + (xs.count > 4 ? " and \(xs.count - 4) more" : "") + "."
                text += " Listings either mention it or don’t, so I can’t rank homes by how much of it they have." + (known ? "" : " Want me to add “\(kc)” to your criteria?")
                if !known { offer = { [weak self] st in self?.fast(self?.applyAsk(st, crits: [kc]) ?? AskReply(bot: "")) ?? AskReply(bot: "") } }
                var nx = s
                if !xs.isEmpty { nx.highlighted = xs.prefix(8).map(\.id); lastList = xs.map(\.id) }
                return bot(text, surface: true, next: nx, sugs: ["Which has the biggest basement?", "Which has the most bedrooms?", "Which one fits me best?"])
            }
            return bot((rankQ ? "I can’t rank homes by that, since the listings don’t include it. " : "I’m not sure I can answer that from the listings. ") + "I can compare homes on price, size, beds, baths, lot size, basement, garage, year built, HOA and time on Redfin, or color pins by distance to parks, schools and transit.",
                       surface: true, sugs: ["Which has the biggest basement?", "Which has the most bedrooms?", "Which has the biggest lot?"])
        }
        let cs = AskText.splitCriteria(t).map { normCrit($0, s, loose: false) }
        if cs.count > 1 { return applyAsk(s, crits: cs) }
        let c = cs.first ?? t.lowercased()
        if s.criteria.contains(c) {
            var nx = s; nx.disabled.remove(c); nx.prune()
            return bot("", tools: ["Turned on “\(c)”"], next: nx)
        }
        var nx = pruned(s); nx.criteria.append(c)
        return bot("Re-ranked by \(AskText.ranked(nx.scoringCriteria.count)).", tools: ["Added “\(c)”"], next: nx)
    }

    // MARK: - Planning, watches, compare (prototype `h2`)

    private func h2(_ lo: String, _ vis: [Listing], _ s: SearchState, pre: String) -> AskReply? {
        let addrs = AskText.addressHits(lo, in: catalog)
        let last = (s.highlighted.count == 1 ? H(s.highlighted[0]) : nil) ?? lastHome.flatMap(H)
        let ranked = { self.bestOf(vis, s).map(\.x) }
        let favs = favorites()
        let ordWords = ["first", "second", "third", "fourth", "fifth", "sixth"]
        let ordIx: () -> Int = {
            guard let m = lo.groups(#"\b(first|second|third|fourth|fifth|sixth|last|1st|2nd|3rd|4th|5th|6th)\b"#), let w = m[1] else { return -1 }
            if w == "last" { return 99 }
            if let d = w.first?.wholeNumberValue { return d - 1 }
            return ordWords.firstIndex(of: w) ?? -1
        }
        let listFrom = { self.debrief ?? self.itinerary?.stops.map(\.listingID) ?? s.tours.map(\.listingID) }
        let pickOrd = { (ids: [String]) -> Listing? in let i = ordIx(); return i < 0 || ids.isEmpty ? nil : self.H(ids[min(i, ids.count - 1)]) }
        let numWords = ["two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "couple": 2]

        if lo.rx(#"\b(my dream home|what do you (know|remember) about (me|us|what i want)|my (saved )?preferences|what have you (saved|learned))\b"#) {
            let must = s.criteria.filter { s.mode(of: $0) == .must }.count, deal = s.criteria.filter { s.mode(of: $0) == .deal }.count
            let nice = s.criteria.count - must - deal, n = s.criteria.count
            return fast(bot(n > 0 ? "I’ve saved \(n)" + (n == 1 ? " preference" : " preferences") + " to your dream home: \(must) must-haves, \(nice) nice-to-haves and \(deal) deal-breakers. You can review and edit them in My home."
                                   : "Nothing is saved to your dream home yet. Tell me what you want, like “a big yard is a must-have,” and I’ll add it.",
                            surface: true, next: pruned(s), cta: AskCTA(label: "Open My home", kind: .myHome)))
        }
        if lo.rx(#"\b(visual )?(inspiration|inspo)\b|\binspire me\b|\b(browse|show me) (home )?styles\b"#) {
            return fast(bot("Tap a look you like and I’ll find homes in your results with that style.", surface: true, next: pruned(s), widget: .inspiration))
        }
        if (lo.rx(#"\b(photo|picture|pic|image|screenshot)\b"#) && lo.rx(#"\b(like|similar|match|look)\b"#)) || lo.rx(#"\b(kitchens?|bathrooms?|exteriors?|countertops?|fireplaces?) like (this|these|that)\b"#) {
            return fast(bot("Add a photo of a home, room or detail you like, and I’ll find homes in your results with a similar look.", surface: true, next: pruned(s), widget: .addPhoto))
        }

        if lo.rx(#"\b(what am i watching|my watch(es|list)|what('s| is| are) (being )?watched|show (me )?(my )?watch(es|list)?)\b"#) {
            let ws = s.watches.filter { $0.status == .on }
            guard !ws.isEmpty else {
                let r0 = ranked().first
                return fast(bot("You’re not watching any homes yet. Try “Watch " + (r0.map(street) ?? "this home") + " and tell me if the price drops.”", surface: true))
            }
            return fast(bot("You’re watching \(AskText.homes(ws.count)).", surface: true, widget: .watch(ws)))
        }
        let watchQ = lo.rx(#"\b(watch|keep an eye on|keep tabs on|monitor)\b"#)
            || (lo.rx(#"\b(tell|let) me (know )?(if|when)\b|\b(notify|alert|ping|text) me\b"#) && lo.rx(#"\b(price|drops?|cut|reduc\w*|pending|under contract|sells?|sold|open house|under \$?\d|below \$?\d|changes?)\b"#))
        if watchQ {
            guard let x = addrs.first ?? last else {
                return fast(bot("Which home should I watch? Tell me the street, or tap a home first.", surface: true,
                                sugs: ranked().prefix(2).map { "Watch \(street($0)) for a price drop" }))
            }
            var v = 0.0
            if let pm = lo.groups(#"(?:under|below|less than|beneath|hits?|reaches?|drops? to|falls? to)\s*\$?\s*(\d[\d,.]*)\s*(k|m|mil|million)?\b"#), let n = pm[1] {
                v = Double(n.replacingOccurrences(of: ",", with: "")) ?? 0
                if let u = pm[2] { v *= u.hasPrefix("k") ? 1e3 : 1e6 } else { v = v < 20 ? v * 1e6 : v < 1e4 ? v * 1e3 : v }
            }
            let money = SearchState.money(Int(v))
            let (cond, label, say): (HomeWatch.Condition, String, String) = v > 0 ? (.price, "Price drops under " + money, "the price drops under " + money)
                : lo.rx("pending|under contract|sells?|sold|off the market") ? (.pending, "It goes pending", "it goes pending")
                : lo.rx("open house") ? (.openHouse, "It schedules an open house", "it schedules an open house")
                : (.anyDrop, "Any price drop", "the price drops")
            let tour = lo.rx(#"\b(book|schedule|set up|request|line up)\b.{0,24}\btours?\b|\btour it\b"#)
            if cond == .price && Int(v) >= x.price {
                return fast(bot("\(street(x)) is already listed at \(x.formattedPrice), under \(money). Want me to set up a tour instead?", surface: true,
                                cta: AskCTA(label: "Schedule a tour", kind: .tour, listingID: x.id)))
            }
            let w = HomeWatch(id: "w\(Int(Date.now.timeIntervalSince1970 * 1000))", listingID: x.id, condition: cond, value: Int(v), label: label, phrase: say, action: tour ? .tour : .tell)
            lastHome = x.id
            var nx = s; nx.watches.append(w)
            return fast(bot("I’m watching \(street(x)) (\(x.formattedPrice)). If \(say), I’ll " + (tour ? "request a tour for the next open slot and tell you here." : "tell you here."),
                            surface: true, tools: ["Watching \(street(x))"], next: nx, widget: .watch([w]), sugs: ["What am I watching?", "Compare it with my top matches"]))
        }

        if var it = itinerary {
            let tm = lo.groups(#"\b(?:start|begin|leave|head out|kick off|starting)\b[^\d]{0,12}(\d{1,2})(?::(\d\d))?\s*(am|pm|a\.m\.|p\.m\.)?"#)
            let rmM = lo.rx(#"\b(remove|drop|skip|cut|take out|lose|delete)\b"#) && (!addrs.isEmpty || ordIx() >= 0)
            let addM = lo.rx(#"\b(add|include|squeeze in)\b"#) && addrs.contains { a in !it.stops.contains { $0.listingID == a.id } }
            let dayM = lo.groups(#"\b(sunday|saturday)\b"#), dayMove = dayM != nil && lo.rx(#"\b(move|switch|change|make it|do it|instead)\b"#)
            if tm != nil || rmM || addM || dayMove {
                var ids = it.stops.map(\.listingID), day = dayMove ? (dayM?[1] == "sunday" ? "Sun" : "Sat") : it.day, start = it.start
                var lead: [String] = []
                if let tm {
                    var h = Int(tm[1] ?? "") ?? 10
                    let mm = Int(tm[2] ?? "") ?? 0, ap = (tm[3] ?? "").replacingOccurrences(of: ".", with: "")
                    if ap == "pm" && h < 12 { h += 12 }
                    if ap == "am" && h == 12 { h = 0 }
                    if ap.isEmpty && h < 8 { h += 12 }
                    start = h * 60 + mm
                    lead.append("Starting at \(Self.clock(start)).")
                }
                if rmM, let x = addrs.first(where: { ids.contains($0.id) }) ?? pickOrd(ids) {
                    if ids.count > 2 { ids.removeAll { $0 == x.id }; lead.append("Removed \(street(x)).") } else { lead.append("I kept \(street(x)), since a tour day needs at least 2 stops.") }
                }
                if addM { for a in addrs where !ids.contains(a.id) { ids.append(a.id); lead.append("Added \(street(a)).") } }
                if day != it.day { lead.append("Moved to \(Self.dayName(day)).") }
                it = planDay(ids, day: day, start: start)
                return fast(itineraryReply(it, s, lead: lead.isEmpty ? "Updated." : lead.joined(separator: " ")))
            }
            if lo.rx(#"\b(request|book|schedule|set up)\b.*\btours?\b"#) && lo.rx(#"\b(all|them|these|every|each|stops)\b"#) { return fast(requestTours(it, s)) }
        }

        let ctxHomes = debrief != nil || itinerary != nil || !s.tours.isEmpty || !addrs.isEmpty
        let rx = lo.groups(#"\b(small|cramped|tiny|tight|dark|dim|gloomy|noisy|loud)\b"#)
        let lovedQ = lo.rx(#"\b(loved|adored|really liked)\b"#), noQ = lo.rx(#"\bnot for (me|us)\b|\b(hated|didn'?t like|did not like)\b"#)
        if ctxHomes && ((rx != nil && lo.rx(#"\b(felt|feels|feel|was|seemed|too|pretty|kind of|bit|little|really|way)\b"#)) || lovedQ || noQ) {
            if let x = addrs.first ?? pickOrd(listFrom()) ?? (debrief?.count == 1 ? debrief.flatMap { H($0[0]) } : nil) ?? last {
                let w = rx?[1] ?? ""
                let k = rx != nil ? (w.rx("dark|dim|gloomy") ? "dark" : w.rx("noisy|loud") ? "noisy" : "small") : lovedQ ? "loved" : "no"
                return reaction(x, k, s)
            }
        }
        if lo.rx(#"\b(debrief|how did (it|they|the tours?|the showings?|the open houses?) go|back from (the |my |our )?(tours?|touring|open houses?|showings?)|after (the |my |our )?(tours?|touring)|(i|we) (just )?(toured|went to see))\b"#) {
            let ids = listFrom()
            guard !ids.isEmpty else { return fast(bot("You haven’t toured any homes with me yet. Want to plan a tour day?", surface: true)) }
            let items = Array(ids.prefix(5))
            debrief = items
            return fast(bot("Welcome back. How did " + (items.count == 1 ? "it" : "they") + " feel in person? Tap a reaction, or just tell me, and I’ll adjust your search.",
                            surface: true, widget: .debrief(items), sugs: ["The second one felt small", "Compare the ones I toured"]))
        }

        if lo.rx(#"\b(compare|comparison|side[- ]by[- ]side|versus|vs\.?|stack (them|these|those) up|head[- ]to[- ]head)\b"#) {
            var xs = addrs
            if xs.count < 2 {
                let fav = catalog.filter { favs.contains($0.id) }, hlL = s.highlighted.compactMap(H)
                let base: [Listing] = lo.rx(#"\b(saved|favou?rites?|hearted)\b"#) && fav.count >= 2 ? fav
                    : lo.rx(#"\b(tour|toured|stops|itinerary)\b"#) && listFrom().count >= 2 ? listFrom().compactMap(H)
                    : hlL.count >= 2 ? hlL : fav.count >= 2 ? fav : ranked()
                for b in base where !xs.contains(b) { xs.append(b) }
            }
            let nW = Int(lo.groups(#"\b([2-4])\b"#)?[1] ?? "") ?? 0
            xs = Array(xs.prefix(nW > 0 ? nW : min(4, xs.count > 3 && !lo.rx(#"\b(top|best)\b"#) ? 4 : 3)))
            guard xs.count >= 2 else { return slow(["Pulling listing details", "Building a comparison"], vis.count, bot("I need at least two homes to compare. Save a few or tell me the streets.", surface: true)) }
            return slow(["Pulling listing details", "Building a comparison"], vis.count,
                        bot(pre + compareSummary(xs), surface: true, tools: ["Compared \(AskText.homes(xs.count))"], next: hi(s, xs.map(\.id), list: xs.map(\.id)),
                            widget: .compare(xs.map(\.id)), sugs: ["Which one fits me best?", "Plan a tour day for these"]))
        }

        let planQ = lo.rx(#"\bopen houses?\b|\btour(ing)? day\b|\bitinerar(y|ies)\b|\bplan (out )?(my |a |an |the |our |this )?(saturday|sunday|weekend|day|tours?|route|showings?|open houses?)\b|\btour (a few|several|some|a couple|\d|two|three|four|five|six|these|them|those|my saved|my favou?rites|the top)\b|\b(route|day) (of|for) (tours|showings|open houses)\b"#)
        if planQ && !lo.rx(#"\b(virtual|3d|video) tour\b"#) {
            let n0 = Int(lo.groups(#"\b([2-6])\b"#)?[1] ?? "") ?? 0
            let nw = numWords.first { lo.rx(#"\b"# + $0.key + #"\b"#) }?.value ?? 0
            let n = max(2, min(6, n0 > 0 ? n0 : nw > 0 ? nw : 4))
            let day = lo.rx(#"\bsunday\b"#) ? "Sun" : "Sat"
            var start = 600
            if let tm = lo.groups(#"\b(?:start|starting|begin|from|at)\b\s*(\d{1,2})(?::(\d\d))?\s*(am|pm)"#) {
                var h = Int(tm[1] ?? "") ?? 10
                if tm[3] == "pm" && h < 12 { h += 12 }
                start = h * 60 + (Int(tm[2] ?? "") ?? 0)
            }
            let R0 = ranked(), fav = R0.filter { favs.contains($0.id) }, oh = R0.filter { $0.facts?.openHouse != nil }
            let hlL = s.highlighted.compactMap(H).filter(vis.contains)
            let theseQ = lo.rx(#"\b(these|them|those)\b"#), savedQ = lo.rx(#"\b(saved|favou?rites?|hearted|liked)\b"#), ohQ = lo.rx(#"\bopen houses?\b"#)
            let (src, why): ([Listing], String) = theseQ && hlL.count >= 2 ? (hlL, "these homes") : savedQ && fav.count >= 2 ? (fav, "your saved homes")
                : ohQ && oh.count >= 2 ? (oh, "the homes with open houses") : fav.count >= 2 ? (fav, "your saved homes") : (R0, "your top matches")
            let pk = Array(src.prefix(n))
            var cand: [Listing] = []
            for x in pk + (ohQ ? oh : []) + fav + R0 where !cand.contains(x) { cand.append(x) }
            cand = Array(cand.prefix(max(8, pk.count)))
            guard cand.count >= 2 else { return fast(bot("There aren’t enough homes in your results to plan a day. Want me to widen your search?", surface: true)) }
            let p = TourPick(day: day, start: start, candidates: cand.map(\.id), selected: Set(pk.map(\.id)))
            pick = p
            return fast(bot("Let’s plan your \(Self.dayName(day)). I picked \(pk.count) of \(why). Check or uncheck homes, then I’ll put them in a route.",
                            surface: true, next: pruned(s), widget: .pick(p), sugs: ["Make it Sunday instead", "Start at 11 AM"]))
        }
        if var p = pick, !p.done {
            let dm = lo.groups(#"\b(sunday|saturday)\b"#), tm = lo.groups(#"\b(?:start|starting|begin)\b[^\d]{0,12}(\d{1,2})(?::(\d\d))?\s*(am|pm)?"#)
            if dm != nil || tm != nil {
                if let dm { p.day = dm[1] == "sunday" ? "Sun" : "Sat" }
                if let tm {
                    var h = Int(tm[1] ?? "") ?? 10
                    if (tm[3] == "pm" || (tm[3] == nil && h < 8)) && h < 12 { h += 12 }
                    p.start = h * 60 + (Int(tm[2] ?? "") ?? 0)
                }
                pick = p
                return fast(bot("Okay, \(Self.dayName(p.day))" + (tm != nil ? " starting at \(Self.clock(p.start))" : "") + ". Pick your homes above and I’ll build the route.", widget: .pick(p)))
            }
        }
        return nil
    }

    // MARK: - Attribute questions (prototype `h3`)

    struct Attr {
        let key: String, pattern: String, chk: String, noun: String, hi: String, lo: String
        var none: String? = nil
        var sep: String? = nil
        let val: (Listing) -> Double?
        let at: (Double, Listing) -> String
        var lead: ((Bool, Listing, Double) -> String)? = nil
        var note: ((String) -> String)? = nil
    }

    private lazy var attrs: [Attr] = {
        let sqf = { (v: Double) in Int(v).formatted() + " sq ft" }
        return [
            Attr(key: "basement", pattern: #"\bbasements?\b"#, chk: "basements", noun: "basement", hi: "biggest", lo: "smallest", none: "a basement",
                 val: { l in l.facts.flatMap { $0.basementSqft > 0 ? Double($0.basementSqft) : nil } },
                 at: { v, l in sqf(v) + " (" + (l.facts?.basementFinished == true ? "finished" : "unfinished") + ")" }),
            Attr(key: "lot", pattern: #"\b(lot|lots|yard|yards|backyard|backyards|acreage)\b"#, chk: "lot sizes", noun: "lot", hi: "biggest", lo: "smallest", none: "a lot size",
                 val: { $0.facts?.lotSqft.map(Double.init) }, at: { v, _ in sqf(v) },
                 note: { $0.rx("yard") ? " I’m going by lot size, since listings don’t break out yard size." : "" }),
            Attr(key: "garage", pattern: #"\b(garages?|parking)\b"#, chk: "garages", noun: "garage", hi: "biggest", lo: "smallest", none: "a garage",
                 val: { l in l.facts.flatMap { $0.garageCars > 0 ? Double($0.garageCars) : nil } }, at: { v, _ in "\(Int(v))" + (v == 1 ? " car" : " cars") }),
            Attr(key: "beds", pattern: #"\bbed(room)?s?\b"#, chk: "bedrooms", noun: "bedrooms", hi: "most", lo: "fewest",
                 val: { $0.beds > 0 ? Double($0.beds) : nil }, at: { v, _ in self.num(v) }),
            Attr(key: "baths", pattern: #"\bbath(room)?s?\b"#, chk: "bathrooms", noun: "bathrooms", hi: "most", lo: "fewest",
                 val: { $0.baths > 0 ? $0.baths : nil }, at: { v, _ in self.num(v) }),
            Attr(key: "sqft", pattern: #"\b(square f(?:ee|oo)tage|sq\.? ?ft|living (?:area|space)|floor area)\b"#, chk: "square footage", noun: "square footage", hi: "most", lo: "least",
                 val: { $0.sqft > 0 ? Double($0.sqft) : nil }, at: { v, _ in sqf(v) }),
            Attr(key: "hoa", pattern: #"\b(hoa|dues|association fees?)\b"#, chk: "HOA fees", noun: "HOA", hi: "highest", lo: "lowest", sep: ", ",
                 val: { Double(HomeCatalog.hoa($0)) }, at: { v, _ in v > 0 ? "an HOA of $\(Int(v)) a month" : "no HOA" },
                 lead: { dMax, x, v in self.street(x) + " has the " + (dMax ? "highest" : "lowest") + " HOA" + (v > 0 ? ", $\(Int(v)) a month." : ": none.") }),
            Attr(key: "price", pattern: #"\bprice\b"#, chk: "prices", noun: "price", hi: "highest", lo: "lowest",
                 val: { Double($0.price) }, at: { v, _ in "$" + Int(v).formatted() }),
            Attr(key: "dom", pattern: #"\b(days on (?:redfin|(?:the )?market)|on (?:the )?market|on redfin|time on (?:redfin|market)|(?:newest|latest|freshest|oldest|stalest) listing|newly listed|been listed)\b"#,
                 chk: "days on Redfin", noun: "time on Redfin", hi: "longest", lo: "shortest", sep: ", ",
                 val: { Double($0.daysOnMarket) }, at: { v, _ in (v == 1 ? "1 day" : "\(Int(v)) days") + " on Redfin" },
                 lead: { dMax, x, v in self.street(x) + (dMax ? " has been on Redfin the longest, " : " is the freshest listing, ") + (v == 1 ? "1 day" : "\(Int(v)) days") + "." }),
            Attr(key: "year", pattern: #"\b(year built|built|newest|oldest|newer|older|vintage)\b"#, chk: "build years", noun: "build year", hi: "newest", lo: "oldest", sep: ", ",
                 val: { Double($0.yearBuilt) }, at: { v, _ in "built in \(Int(v))" },
                 lead: { dMax, x, v in self.street(x) + " is the " + (dMax ? "newest" : "oldest") + " home, built in \(Int(v))." }),
        ]
    }()

    private func h3(_ lo0: String, _ vis: [Listing], _ s: SearchState, pre: String) -> AskReply? {
        let N = vis.count
        let lo = lo0.replacingRx(#"\bmost recent(ly)?\b"#, with: "newest").replacingRx(#"\bleast recent(ly)?\b"#, with: "oldest")
        if lo.rx(#"\b(average|avg|mean|median|typical|total|sort|order|colou?r|shade|heat ?map|closer|closest|near|nearest|distance|walk|drive|commute|per (sq|square)|ppsf|under|over|below|above|less than|more than|at least|at most|no more than|up to)\b"#) { return nil }
        let sup = lo.groups(#"\b(biggest|largest|most|highest|greatest|longest|maximum|max|smallest|least|lowest|fewest|tiniest|shortest|minimum|min|newest|oldest)\b"#)?[1] ?? nil
        let a = attrs.first { lo.rx($0.pattern) }
        let addrHit = AskText.addressHits(lo, in: catalog).first
        let hlOne = s.highlighted.count == 1, curId = (hlOne ? s.highlighted.first : nil) ?? lastHome
        let nextRx = #"\b(next (one|best|biggest|largest|home|house)|the next one|runner[- ]?up|and after that|another one)\b|^(and |what about |how about )?(the )?next\??$"#
        let prevRx = #"\b(previous (one|home|house)|the one before|go back|back to (the )?(last|previous))\b"#

        // "And the next one?" walks down the last ranked list.
        if a == nil && (lo.rx(nextRx) || lo.rx(prevRx)) && !lo.rx(#"\b(tour|schedule|book|watch|afford|compare|similar)\b"#) {
            let sameList = lastAttr.map { $0.ids == lastList } ?? false
            let ids = (sameList ? lastAttr!.ids : lastList).filter { id in vis.contains { $0.id == id } }
            if ids.count > 1 {
                let fwd = lo.rx(nextRx), i = curId.flatMap(ids.firstIndex(of:)) ?? -1, j = fwd ? (i < 0 ? 1 : i + 1) : (i < 0 ? 0 : i - 1)
                guard j >= 0, j < ids.count else {
                    return fast(bot(fwd ? "That was the last of the \(AskText.homes(ids.count)) I listed. Want me to widen your search?" : "That’s the first one on my list.", surface: true))
                }
                guard let x = H(ids[j]) else { return nil }
                let line: String
                if sameList, let la = lastAttr, let v = la.vals[x.id] {
                    line = (fwd ? "Next is " : "Back to ") + street(x) + (la.attr.sep ?? " at ") + la.attr.at(v, x) + "."
                } else {
                    line = (fwd ? "Next on my list is " : "Back to ") + "\(street(x)): \(x.formattedPrice), \(x.beds) bd, \(x.bathsFormatted) ba, \(sqftText(x)) sq ft."
                }
                return fast(bot(line, next: hi(s, [x.id], list: ids), sugs: [j < ids.count - 1 ? "And the next one?" : "Which one fits me best?", "Does it have a garage?", "Homes like this one"]))
            }
        }

        // "Which has the biggest basement?"
        if let sup, let a {
            var dMax = !sup.rx(#"^(smallest|least|lowest|fewest|tiniest|shortest|minimum|min|oldest)$"#)
            if a.key == "dom" { dMax = lo.rx(#"\b(newest|latest|freshest) listing|\bnewly listed\b"#) ? false : lo.rx(#"\b(oldest|stalest) listing"#) ? true : dMax }
            let steps = ["Checking " + a.chk, "Comparing homes"]
            guard N > 0 else {
                offer = expandOffer
                return slow(steps, N, bot("There aren’t any homes in your results to compare. Want me to expand your search area?", surface: true))
            }
            let refBack = lo.rx(#"\b(of|among|from) (those|them|these)\b|\bin that list\b"#)
            let hlL = s.highlighted.compactMap(H).filter(vis.contains), prior = lastList.compactMap(H).filter(vis.contains)
            let poolL = refBack ? (hlL.count > 1 ? hlL : prior.count > 1 ? prior : vis) : vis, M = poolL.count
            let rows = poolL.compactMap { x in a.val(x).map { (x: x, v: $0) } }.sorted { dMax ? $0.v > $1.v : $0.v < $1.v }
            guard let top = rows.first else {
                offer = expandOffer
                return slow(steps, N, bot(pre + (M == 1 ? "The 1 home in your results doesn’t list " : "None of the \(M) homes in your results list ") + (a.none ?? "that") + ". Want me to expand your search area?", surface: true))
            }
            let x = top.x, ids = rows.map(\.x.id), ties = rows.filter { $0.v == top.v }.count, miss = M - rows.count
            lastAttr = (a, dMax, ids, Dictionary(uniqueKeysWithValues: rows.map { ($0.x.id, $0.v) }))
            var text = pre + (a.lead?(dMax, x, top.v) ?? "\(street(x)) has the \(dMax ? a.hi : a.lo) \(a.noun) at \(a.at(top.v, x)).")
            if rows.count == 1 { text += M > 1 ? " It’s the only home" + (a.none.map { " that lists " + $0 } ?? "") + " in your results." : "" }
            else if ties > 1 { text += " \(ties - 1)" + (ties == 2 ? " other home ties" : " other homes tie") + " with it, so I picked the first in your list." }
            else { text += " Next is \(street(rows[1].x))" + (a.sep ?? " at ") + a.at(rows[1].v, rows[1].x) + "." }
            if miss > 0, let none = a.none { text += " \(miss)" + (miss == 1 ? " home doesn’t" : " homes don’t") + " list \(none)." }
            if let note = a.note { text += note(lo) }
            if refBack && M != N { text += " From the \(AskText.homes(M)) I listed." }
            return slow(steps, N, bot(text, next: hi(s, [x.id], list: ids),
                                     sugs: rows.count > 1 ? ["And the next one?", "Homes like this one", "Can I afford it?"] : ["Homes like this one", "Can I afford it?", "Does it have a garage?"]))
        }

        // "How big is its basement?" about the highlighted home.
        let pron = lo.rx(#"\b(it|its|that one|this one|that home|that house|that place|the home|the house)\b"#)
        if sup == nil, a != nil, addrHit == nil, let curId,
           (hlOne && lo.rx(#"^(how|what|whats|what's|is there|does|do|any|got)\b"#)) || (pron && lo.rx(#"\b(does|do|is|has|have|what|how|when|any|got)\b"#)),
           !lo.rx(#"\b(which|homes|houses|results|listings|all|how many (homes|houses|listings))\b"#),
           let x = H(curId) {
            let ans = propAnswer(x, lo, "It", optional: true)
            if !ans.isEmpty { return fast(bot(ans, next: pruned(s))) }
        }
        return nil
    }

    // MARK: - Tour days, reactions, compare, photos

    static func dayName(_ d: String) -> String { d == "Sun" ? "Sunday" : "Saturday" }

    /// "10:30 AM" from minutes after midnight.
    static func clock(_ m: Int) -> String {
        let h = m / 60, mm = m % 60
        return "\((h + 11) % 12 + 1):" + String(format: "%02d", mm) + (h < 12 ? " AM" : " PM")
    }

    /// Orders stops north to south by nearest neighbor; 30 min per visit.
    func planDay(_ ids: [String], day: String, start: Int) -> TourPlan {
        var rest = ids.compactMap(H).sorted { $0.latitude > $1.latitude }
        var ord: [Listing] = []
        if !rest.isEmpty { ord.append(rest.removeFirst()) }
        let km = { (a: Listing, b: Listing) in TravelTime.miles(a.latitude, a.longitude, b.latitude, b.longitude) * 1.609344 }
        while !rest.isEmpty, let cur = ord.last {
            rest.sort { km(cur, $0) < km(cur, $1) }
            ord.append(rest.removeFirst())
        }
        var t = start
        let stops = ord.enumerated().map { i, x -> TourPlan.Stop in
            let drive = i == 0 ? 0 : max(4, Int((km(ord[i - 1], x) * 2.4 + 3).rounded()))
            t += drive
            let at = t
            t += 30
            return TourPlan.Stop(listingID: x.id, at: at, drive: drive)
        }
        return TourPlan(day: day, start: start, stops: stops, end: t, driveTotal: stops.reduce(0) { $0 + $1.drive })
    }

    /// The reply for a planned day; also called when the picker is confirmed.
    func itineraryReply(_ plan: TourPlan, _ s: SearchState, lead: String? = nil) -> AskReply {
        itinerary = plan
        pick?.done = true
        let n = plan.stops.count
        var nx = s; nx.highlighted = plan.stops.map(\.listingID)
        let text = (lead.map { $0 + " " } ?? "Here’s your \(Self.dayName(plan.day)). ") + "\(n) stops from \(Self.clock(plan.stops.first?.at ?? plan.start)) to about \(Self.clock(plan.end)), with \(plan.driveTotal) minutes of driving. I ordered them to keep drive time short."
        return bot(text, surface: true, tools: ["Planned \(n) stops for \(Self.dayName(plan.day))"], next: nx, widget: .itinerary(plan),
                   sugs: ["Start at 11 AM", "Remove the last stop", "Compare these homes"])
    }

    func requestTours(_ plan: TourPlan, _ s: SearchState) -> AskReply {
        var p = plan; p.requested = true; itinerary = p
        let ids = plan.stops.map(\.listingID)
        var nx = s
        nx.tours.removeAll { ids.contains($0.listingID) }
        nx.tours += plan.stops.map { ScheduledTour(listingID: $0.listingID, day: Self.dayName(plan.day), time: Self.clock($0.at)) }
        return bot("Done. A Redfin agent will confirm each time by text. After your tours, tell me how they felt and I’ll adjust your search.",
                   surface: true, tools: ["Requested tours of \(AskText.homes(ids.count)) for \(Self.dayName(plan.day))"], next: nx,
                   sugs: ["I’m back from touring", "Compare these homes"])
    }

    /// A debrief reaction: smaller → offer a size minimum, dark → natural light
    /// must-have, noisy → quiet street must-have, loved → similar homes, no → hide.
    func reaction(_ x: Listing, _ k: String, _ s: SearchState) -> AskReply {
        switch k {
        case "small":
            guard x.sqft > 0 else { return fast(bot("Noted. \(street(x)) doesn’t list its square footage, so tell me a minimum you’d like, like “at least 2,000 sq ft.”", surface: true)) }
            let v = Int((Double(x.sqft) * 1.15 / 100).rounded(.up)) * 100
            var nx = s; nx.filters.minSqft = v
            let n = count(nx), vs = v.formatted()
            return fast(bot("Got it. \(street(x)) is \(sqftText(x)) sq ft. Want me to set a minimum of \(vs) sq ft? That leaves \(AskText.homes(n)) in your results.",
                            surface: true, widget: .confirmMinSqft(v, yes: "Set minimum to \(vs) sq ft", no: "Keep as is")))
        case "dark": return fast(setMode(s, "natural light", .must))
        case "noisy": return fast(setMode(s, "quiet street", .must))
        case "loved":
            var r = similar(x, s, pre: "Glad you liked \(street(x)). ")
            r.slow = true; r.steps = ["Comparing price, size and location", "Finding the closest matches"]; r.workDone = "Compared homes"
            return r
        default:
            var nx = s; nx.hidden.insert(x.id); nx.highlighted.removeAll { $0 == x.id }
            return fast(bot("Noted. I’ll leave \(street(x)) out of your results.", tools: ["Hid \(street(x))"], next: nx))
        }
    }

    /// "Simulate a trigger" on a watch card: the price drops, it goes pending
    /// or it schedules an open house; a tour watch also requests the tour.
    func triggerWatch(_ w: HomeWatch, _ s: SearchState) -> AskReply {
        guard let x = H(w.listingID) else { return AskReply(bot: "") }
        let p0 = x.price
        let np = w.condition == .price ? Int(floor(Double(w.value - 5000) / 5000)) * 5000 : Int((Double(p0) * 0.96 / 5000).rounded()) * 5000
        let tour = w.action == .tour && w.condition != .pending
        let lead: String
        switch w.condition {
        case .pending: lead = "\(street(x)) just went pending, so I stopped watching it."
        case .openHouse: lead = "\(street(x)) scheduled an open house for Sunday, 1:00 to 3:00 PM."
        case .price, .anyDrop:
            lead = "Price drop on \(street(x)): it’s now $\(np.formatted()), down from \(x.formattedFullPrice)." + (w.condition == .price ? " That’s under your \(SearchState.money(w.value)) limit." : "")
        }
        let tail = tour ? " As you asked, I requested a tour for Saturday at 11:00 AM. A Redfin agent will confirm by text."
            : w.condition == .pending ? " Want to see homes like it?" : " Want me to set up a tour?"
        var nx = s
        if let i = nx.watches.firstIndex(where: { $0.id == w.id }) { nx.watches[i].status = .hit }
        if tour {
            nx.tours.removeAll { $0.listingID == x.id }
            nx.tours.append(ScheduledTour(listingID: x.id, day: "Saturday", time: "11:00 AM"))
        }
        lastHome = x.id
        return bot(lead + tail, surface: true, tools: ["Watch triggered on \(street(x))"], next: nx,
                   cta: !tour && w.condition != .pending ? AskCTA(label: "Schedule a tour", kind: .tour, listingID: x.id) : nil,
                   widget: .homes([x.id], total: 1))
    }

    func stopWatch(_ w: HomeWatch, _ s: SearchState) -> AskReply {
        var nx = s
        if let i = nx.watches.firstIndex(where: { $0.id == w.id }) { nx.watches[i].status = .off }
        return bot("", tools: ["Stopped watching " + (H(w.listingID).map(street) ?? "that home")], next: nx)
    }

    /// "Find homes that match" on Dream Home: scours the listings with the
    /// dream home's must-haves, dealbreakers and nice-to-haves.
    func findDream(_ s: SearchState) -> AskReply {
        let areas = AskText.joinAnd(s.locations.map { $0.replacingOccurrences(of: ", WA", with: "") })
        let poolN = pool(s).count, must = s.dreamMustHaves.count, nice = s.dreamNiceToHaves.count, deal = s.dreamDealBreakers.count
        let n = { (k: Int, one: String, many: String) in "\(k) " + (k == 1 ? one : many) }
        var steps = ["Reading your dream home", "Scouring \(poolN) listings in \(areas)"]
        if must > 0 { steps.append("Applying " + n(must, "must-have", "must-haves")) }
        if deal > 0 { steps.append("Ruling out homes with " + (deal == 1 ? "a dealbreaker" : "dealbreakers")) }
        if nice > 0 { steps.append("Scoring " + n(nice, "nice-to-have", "nice-to-haves")) }
        steps.append("Ranking your best matches")

        let nx = pruned(s), vis = visible(nx), N = vis.count
        var r: AskReply
        if N == 0 {
            offer = expandOffer
            r = bot("No homes in \(areas) fit your dream home yet. Want me to widen the area or loosen a must-have?", surface: true, next: nx)
        } else {
            let ranked = bestOf(vis, nx), top = ranked[0], x = top.x, m = nx.scoringCriteria.count, k = top.ok.count
            lastHome = x.id
            lastList = ranked.map(\.x.id)
            let fit = m == 0 ? "" : ", which matches " + (m == 1 ? (k > 0 ? "your criterion" : "none of your criteria") : (k == m ? "all \(m)" : "\(k) of \(m)") + " of your criteria")
            let text = "Found \(AskText.homes(N)) in \(areas) that fit your dream home" + (must > 0 ? ", each meeting " + (must == 1 ? "your must-have" : "all \(must) of your must-haves") : "")
                + ". \(street(x)) (\(x.formattedPrice)) is the best fit\(fit)."
            var hx = nx; hx.highlighted = [x.id]
            r = bot(text, surface: true, tools: ["Matched homes to your dream home"], next: hx,
                    sugs: ["Can I afford it?", "Homes like this one", "Tour \(street(x))"])
        }
        r.slow = true
        r.steps = steps
        r.workDone = "Searched \(poolN) listings"
        return r
    }

    /// Applies the "Set minimum" confirm from a size reaction.
    func setMinSqft(_ v: Int, _ s: SearchState) -> AskReply {
        var nx = s; nx.filters.minSqft = v
        return bot("Showing \(AskText.homes(count(nx))) with at least \(v.formatted()) sq ft.", tools: ["Set minimum square feet to \(v.formatted())"], next: nx)
    }

    private func compareSummary(_ xs: [Listing]) -> String {
        let pp = { (x: Listing) in x.sqft > 0 ? Double(x.price) / Double(x.sqft) : .infinity }
        let cheap = xs.min { $0.price < $1.price }!, val = xs.min { pp($0) < pp($1) }!, big = xs.max { $0.sqft < $1.sqft }!
        var out = ["\(street(cheap)) has the lowest price, at \(cheap.formattedPrice)."]
        if val != cheap && pp(val).isFinite { out.append("\(street(val)) costs the least per sq ft, at $\(Int(pp(val).rounded())).") }
        if big != cheap && big != val && big.sqft > 0 { out.append("\(street(big)) is the largest, at \(sqftText(big)) sq ft.") }
        return "Here they are side by side. " + out.joined(separator: " ") + " Green marks the best in each row."
    }

    /// "Find homes that look like this": the photo's style comes from a hash
    /// of the file (the prototype can't see images either).
    func photoMatch(seed: String, _ s: SearchState, hasPhoto: Bool = true) -> AskReply {
        let st = Self.photoStyles[Int(HomeCatalog.hash(seed) % UInt32(Self.photoStyles.count))]
        let xs = visible(s).filter { ($0.facts?.photoName ?? "").contains(st.key) }
        guard !xs.isEmpty else {
            return bot("Your photo shows \(st.text). None of the homes in your results have that look. Want me to widen your search?", surface: true)
        }
        var nx = pruned(s)
        nx.refinements.removeAll { $0.id == "photo" }
        nx.refinements.append(SearchRefinement(id: "photo", label: "Looks like your photo", listingIDs: xs.map(\.id)))
        nx.highlighted = xs.prefix(8).map(\.id)
        lastList = xs.map(\.id)
        var r = bot((hasPhoto ? "Your photo shows " : "That look is ") + st.text + ". \(AskText.homes(xs.count)) in your results " + (xs.count == 1 ? "has" : "have") + " a similar look.",
                    tools: ["Matched homes to your photo"], next: nx, sugs: ["Compare the top 3", "Plan a tour day for these"])
        r.slow = true
        r.steps = ["Looking at your photo", "Finding homes with a similar look"]
        r.workDone = "Checked your results"
        return r
    }

    /// Tapping an inspiration tile ("Craftsman") runs the same style match.
    func styleMatch(_ key: String, _ s: SearchState) -> AskReply {
        let seed = Self.photoStyles.firstIndex { $0.key == key }.map { i in (0..<10_000).map(String.init).first { Int(HomeCatalog.hash($0) % UInt32(Self.photoStyles.count)) == i } ?? "" } ?? ""
        return photoMatch(seed: seed, s, hasPhoto: false)
    }
}
