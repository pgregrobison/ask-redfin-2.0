import Foundation

/// What a chat turn does: tool confirmations, an optional work line, the
/// reply, the next search state, follow-up suggestions and any CTA or widget.
struct AskReply {
    var tools: [String] = []
    /// "Checked 26 homes", shown after slow requests.
    var workDone: String? = nil
    var bot: String
    /// Show the reply in the floating bubble even when there's a confirmation.
    var surface = false
    /// Slow requests take longer and show the step list in chat.
    var slow = false
    var steps: [String] = []
    var suggestions: [String] = []
    /// The search after this turn (applied when the reply lands, undoable).
    var next: SearchState? = nil
    var cta: AskCTA? = nil
    var widget: AskWidget? = nil
    /// Session-level actions the router can't do itself.
    var action: Action? = nil

    enum Action { case recall, freshStart(full: Bool) }

    init(bot: String) { self.bot = bot }
}

nonisolated enum AskSteps {
    /// The prototype's `barSteps`: what the closed-chat bar says while working.
    static func bar(for text: String, reply: AskReply, filters: HomeFilters) -> [String] {
        if reply.slow { return ["Understanding your question"] + reply.steps }
        let lo = text.lowercased()
        let ask = AskText.parseAsk(text, filters)
        var out = ["Understanding your request"]
        let places = SearchRegions.shared.places.filter { $0.kind != "School district" }.map { $0.name.replacingOccurrences(of: ", WA", with: "") }
            .filter { lo.rx(#"\b"# + AskText.esc($0.lowercased()) + #"\b"#) }
        if !places.isEmpty { out.append("Finding " + AskText.joinAnd(places)) }
        if ask.patch.touchesPrice { out.append("Adjusting your price range") }
        if ask.patch.touchesRooms || ask.expose.contains("rooms") { out.append("Adjusting beds and baths") }
        if lo.rx(#"\b(fresh|new search|start over|scratch|forget)\b"#) {
            out.append("Clearing your search")
        } else if out.count == 1 {
            out.append(lo.rx(#"\?$|^(which|what|does|is|are|how|can)\b"#) ? "Checking your results" : "Matching homes to what you asked")
        }
        return out + ["Updating results"]
    }
}
