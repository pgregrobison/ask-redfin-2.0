import Foundation

/// What a chat turn does: tool confirmations, an optional work line, the
/// reply, an optional search change and follow-up suggestions.
struct AskReply {
    var tools: [String] = []
    /// "Checked 26 homes", shown after slow requests.
    var workDone: String? = nil
    var bot: String
    /// Show the reply in the floating bubble even when there's a confirmation.
    var surface = false
    /// Slow requests show the step list in chat.
    var slow = false
    var steps: [String] = []
    var suggestions: [String] = []
    /// Applied to the search when the reply lands (undoable).
    var change: ((inout SearchState) -> Void)? = nil
    /// Session-level actions the responder can't do itself.
    var action: Action? = nil

    enum Action { case recall, freshStart }
}

/// Phase 3 stand-in for the prototype's intent router: maps requests onto
/// the search through the existing scripted `ChatService`, plus memory and
/// saved-search commands. Phase 4 replaces this with the full router.
@MainActor
struct AskResponder {
    private let chat = ChatService()

    func reply(to text: String, search: SearchState, listings: [Listing]) -> AskReply {
        let lo = text.lowercased()
        var r = AskReply(bot: "")
        r.steps = Self.steps(for: text)

        if lo.contains("pick up where i left off") || lo.contains("where we left off") {
            r.action = .recall
            return r
        }
        if lo.range(of: #"\b(start fresh|new search|start over|from scratch)\b"#, options: .regularExpression) != nil {
            r.action = .freshStart
            return r
        }
        if lo.range(of: #"\bsave (my |this )?search\b"#, options: .regularExpression) != nil {
            r.tools = ["Saved search"]
            r.bot = "Saved. I’ll let you know when new homes match."
            r.change = { $0.savedSearch = true }
            return r
        }

        switch chat.matchResponse(for: text) {
        case .listings(_, let filters, let add):
            var draft = search
            var tools: [String] = []
            let regions = SearchRegions.shared
            if let names = filters.neighborhoods?.map({ regions.canonicalName($0) }), !names.isEmpty, names != search.locations {
                draft.locations = add ? names.reduce(search.locations) { regions.adding($1, to: $0) } : names
                tools.append(add ? "Added \(Self.join(names))" : "Moved your search to \(Self.join(names))")
            }
            var set: [String] = []
            if let v = filters.maxPrice { draft.filters.maxPrice = v; set.append("price to up to \(SearchState.money(v))") }
            if let v = filters.minPrice { draft.filters.minPrice = v; set.append("price to \(SearchState.money(v))+") }
            if let v = filters.minBeds { draft.filters.beds = v; set.append("\(v)+ beds") }
            if let v = filters.minBaths { draft.filters.baths = v; set.append("\(v.formatted())+ baths") }
            if let v = filters.propertyType, HomeCatalog.homeTypes.contains(v) { draft.filters.types = [v]; set.append("home type to \(v.lowercased())") }
            if !set.isEmpty { tools.append("Set " + Self.join(set)) }
            if filters.minBeds != nil || filters.minBaths != nil, !draft.exposed.contains("rooms") { draft.exposed.append("rooms") }

            let n = SearchEngine.count(listings, draft)
            let k = draft.scoringCriteria.count
            r.tools = tools
            r.bot = n == 0
                ? "No homes in \(draft.locationPhrase) match that yet. Want me to widen the area or raise your price?"
                : "Showing \(Self.homes(n)) in \(draft.locationPhrase)\(draft.pricePhrase)" + (k > 0 ? ", ranked by your \(k == 1 ? "criterion" : "\(k) criteria")." : ".")
            r.surface = n == 0
            if draft != search { r.change = { $0 = draft } }
            r.suggestions = ["Which one fits me best?", "Which has the best transit score?", "Does the cheapest one have a garage?"]
        case .tour(let text, _):
            r.bot = text + " Tour booking from chat arrives in a later update; for now, open a home and tap Request a tour."
            r.surface = true
        case .mortgage(let text, _):
            r.bot = text + " Prequalifying from chat arrives in a later update."
            r.surface = true
        case .staleChat(let text), .fallback(let text):
            r.bot = text
            r.surface = true
        }
        return r
    }

    /// The prototype's `barSteps`: what the bar says while working.
    static func steps(for text: String) -> [String] {
        let lo = text.lowercased()
        var out = ["Understanding your request"]
        let places = SearchRegions.shared.places.filter { $0.kind != "School district" }.map { $0.name.replacingOccurrences(of: ", WA", with: "") }
            .filter { lo.range(of: "\\b\(NSRegularExpression.escapedPattern(for: $0.lowercased()))\\b", options: .regularExpression) != nil }
        if !places.isEmpty { out.append("Finding \(join(places))") }
        if lo.range(of: #"\$|\d\s*(k|m)\b|price|budget|under|over"#, options: .regularExpression) != nil { out.append("Adjusting your price range") }
        if lo.range(of: #"\b(bed|bath|bd|ba|br)"#, options: .regularExpression) != nil { out.append("Adjusting beds and baths") }
        if lo.range(of: #"\b(fresh|new search|start over|scratch|forget)\b"#, options: .regularExpression) != nil {
            out.append("Clearing your search")
        } else if out.count == 1 {
            out.append(lo.hasSuffix("?") || lo.range(of: #"^(which|what|does|is|are|how|can)\b"#, options: .regularExpression) != nil
                       ? "Checking your results" : "Matching homes to what you asked")
        }
        return out + ["Updating results"]
    }

    static func join(_ a: [String]) -> String {
        a.count < 2 ? (a.first ?? "") : a.dropLast().joined(separator: ", ") + " and " + a.last!
    }

    static func homes(_ n: Int) -> String { n == 1 ? "1 home" : "\(n) homes" }
}
