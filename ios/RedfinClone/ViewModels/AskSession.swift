import SwiftUI
import UIKit

/// One row of the Ask Redfin conversation.
struct AskEntry: Identifiable, Equatable {
    enum Kind: Equatable { case user, tool, bot, work }
    enum Feedback: Equatable { case up, down }

    let id = UUID()
    var kind: Kind
    var text: String
    var photo: URL? = nil
    /// Search before this turn changed it (bot rows only), for "Undo change".
    var undo: SearchState.Snapshot? = nil
    var feedback: Feedback? = nil
    /// Characters revealed so far while streaming; nil once fully shown.
    var revealed: Int? = nil
    var cta: AskCTA? = nil
    var widget: AskWidget? = nil
    /// Home cards attached under a reply, and how many homes "Show N on map" means.
    var homes: [String] = []
    var homesTotal = 0
    /// What you've done with the widget (picked, reacted, used).
    var widgetState = AskWidgetState()

    /// Criteria and memory confirmations link to the dream home.
    var linksDreamHome: Bool {
        kind == .tool && text.range(of: #"must-have|dealbreaker|nice-to-have|^Added “|^Removed “|“|square feet|^Set (beds|baths|price)"#,
                                    options: [.regularExpression, .caseInsensitive]) != nil
    }
}

/// The in-bar status while the chat is closed.
enum AskBarToast: Equatable {
    case thinking(String)
    case done(String)
}

/// Drives the iOS Vision Ask Redfin experience: the shared bar, the chat
/// sheet, working states, streaming replies, feedback and threads. Search
/// state lives in `ListingsViewModel`; this owns the conversation.
@Observable
@MainActor
final class AskSession {
    let listings: ListingsViewModel
    /// The intent router; remembers what the conversation points at.
    let router: AskRouter

    static let opensChatForAttachments = true
    static let greeting = "Hi! Tell me what you want in a home, in your own words."
    static let introQuery = "Homes in Seattle under $1.3M with natural light, a finished basement, a large yard, a home office and a quiet street"
    static let disclaimer = "This chat is powered by AI and may process your input to help improve our service. We do not sell your data. AI is occasionally inaccurate. Verify important information."
    static let suggestionPool = [
        "Which one fits me best?", "Homes on Phinney Ave N", "Which has the biggest basement?", "Within a 20 min drive of South Lake Union",
        "Make quiet street a must-have", "Which of these are short sales?", "Does the cheapest one have a garage?", "Which has the best transit score?",
        "Sort by distance to grocery stores", "What’s the average HOA for condos?", "Which cheaper homes are in good condition?", "Closest to Green Lake first",
    ]

    // Conversation
    var entries: [AskEntry] = []
    var draft = ""
    private(set) var suggestions: [String] = []
    private(set) var threadID = "t\(Int(Date.now.timeIntervalSince1970 * 1000))"
    private(set) var threadTitle: String?

    // Working state
    private(set) var isBusy = false
    private(set) var steps: [String] = []
    private(set) var stepIndex = 0
    /// Slow requests switch from dots to the step list after 3s.
    private(set) var showsStepper = false
    private(set) var isStreaming = false

    // Closed-chat chrome
    private(set) var barToast: AskBarToast?
    private(set) var bubbleText: String?
    private(set) var bubbleRevealed: Int?
    /// The keyboard composer over the map.
    var isComposing = false

    // Handoffs and pickers the chat sheet presents
    /// A tapped CTA (tour, Rocket, agent); the chat sheet presents its flow.
    var handoff: AskCTA?
    /// The "Add a photo" widget asks the chat sheet to open the picker.
    var photoPickerRequested = false
    /// Switches to the My home tab ("Open My home").
    var onOpenMyHome: (() -> Void)?

    // Feedback
    private(set) var feedbackAsk: (entryID: UUID, canUndo: Bool)?
    var feedbackFormEntry: UUID?
    private(set) var thanksToast = false

    private var pendingHomes: ([String], Int) = ([], 0)
    private var toastTask: Task<Void, Never>?
    private var bubbleTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    var isChatOpen: Bool {
        get { listings.showChat }
        set { listings.showChat = newValue }
    }

    /// Rotating bar placeholders; the third names the most common street.
    let placeholders: [String]

    init(listings: ListingsViewModel) {
        self.listings = listings
        router = AskRouter(listings: listings.listings, favorites: { [weak listings] in listings?.savedListingIDs ?? [] })
        placeholders = ["Add to or analyze your search", "Color pins by distance to parks",
                        "Homes on \(Self.mostCommonStreet(listings.listings) ?? "Phinney Ave N")",
                        "Which has the best transit score?", "Which has the biggest basement?"]
        // The app opens on the prototype's typed-in scenario (Phase 8 animates it).
        let n = listings.rankedResults.count
        entries = [
            AskEntry(kind: .bot, text: Self.greeting),
            AskEntry(kind: .user, text: Self.introQuery),
            AskEntry(kind: .tool, text: "Set price to up to $1.3M and added 5 criteria"),
            AskEntry(kind: .bot, text: "Here are \(n) homes in Seattle under $1.3M, ranked by how many of your 5 criteria they match."),
        ]
        suggestions = Array(Self.suggestionPool.prefix(3))
        syncLog()
    }

    // MARK: - Intro

    /// The prototype's auto-played opening: the request types itself into the
    /// Ask bar, the send button lights up and presses, and it runs like any
    /// other request.
    enum IntroPhase { case idle, pending, typing, aim, press }
    private(set) var introPhase: IntroPhase = .idle
    private var introTask: Task<Void, Never>?
    var isPlayingIntro: Bool { introPhase != .idle }

    /// Clears the search and chat back to the empty Seattle map, ready for
    /// `playIntro()` (run straight away, or once the splash hands off).
    func prepareIntro() {
        introTask?.cancel()
        guard !isBusy else { return }
        listings.showChat = false
        listings.search.clearSearch()
        entries = [AskEntry(kind: .bot, text: Self.greeting)]
        suggestions = []
        draft = ""
        isComposing = false
        clearBubble()
        syncLog()
        introPhase = .pending
    }

    func playIntro() {
        if introPhase == .idle { prepareIntro() }
        guard introPhase == .pending else { return }
        introPhase = .typing
        let query = Self.introQuery
        introTask = Task {
            let reduce = UIAccessibility.isReduceMotionEnabled
            try? await Task.sleep(for: .milliseconds(1200))
            if reduce {
                draft = query
                try? await Task.sleep(for: .milliseconds(600))
            } else {
                for (i, ch) in query.enumerated() {
                    guard !Task.isCancelled else { return }
                    draft.append(ch)
                    let ms = 26 + (ch == " " ? 30 : 0) + (ch == "," ? 160 : 0) + ((i + 1) * 37) % 17
                    try? await Task.sleep(for: .milliseconds(ms))
                }
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(450))
            introPhase = .aim
            try? await Task.sleep(for: .milliseconds(reduce ? 300 : 750))
            guard !Task.isCancelled else { return }
            introPhase = .press
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            finishIntro()
        }
    }

    /// Tapping the bar mid-intro skips to sending the request.
    func skipIntro() {
        guard introPhase != .idle else { return }
        introTask?.cancel()
        finishIntro()
    }

    /// Lands the prototype's `filled()` turn rather than routing the query,
    /// so the opening reads exactly as designed.
    private func finishIntro() {
        introPhase = .idle
        draft = ""
        entries.append(AskEntry(kind: .user, text: Self.introQuery))
        syncLog()
        var next = listings.search
        next.filters.maxPrice = SearchState.introScenario.filters.maxPrice
        next.criteria = SearchState.introScenario.criteria
        let n = SearchEngine.results(listings.listings, next).count
        var reply = AskReply(bot: "Here are \(n) homes in Seattle under $1.3M, ranked by how many of your \(next.criteria.count) criteria they match.")
        reply.tools = ["Set price to up to $1.3M and added \(next.criteria.count) criteria"]
        reply.next = next
        reply.suggestions = Array(Self.suggestionPool.prefix(3))
        run(reply, barSteps: ["Understanding your request", "Adjusting your price range", "Matching homes to what you asked", "Updating results"])
    }

    // MARK: - Sending

    func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        send(text)
    }

    func send(_ text: String, photo: URL? = nil) {
        guard !isBusy else { return }
        if introPhase != .idle { introTask?.cancel(); introPhase = .idle }
        draft = ""
        isComposing = false
        suggestions = []
        dismissFeedback()
        clearBubble()
        entries.append(AskEntry(kind: .user, text: text, photo: photo))
        syncLog()

        let reply: AskReply
        if let photo {
            let size = (try? FileManager.default.attributesOfItem(atPath: photo.path)[.size] as? Int) ?? 0
            reply = router.photoMatch(seed: photo.lastPathComponent + "\(size)", listings.search)
        } else {
            reply = router.route(text, listings.search)
        }
        run(reply, barSteps: AskSteps.bar(for: text, reply: reply, filters: listings.search.filters))
    }

    func retry() {
        guard let last = entries.last(where: { $0.kind == .user }) else { return }
        send(last.text, photo: last.photo)
    }

    /// Runs a reply through the working state, then lands it. Widget taps
    /// and other UI actions use this too, so they read like a chat turn.
    func run(_ reply: AskReply, barSteps: [String]? = nil) {
        isBusy = true
        // Closed chat: the bar walks through its steps. Open: dots, then the
        // step list for slow requests.
        steps = isChatOpen ? (reply.steps.isEmpty ? ["Thinking"] : reply.steps) : (barSteps ?? (reply.steps.isEmpty ? ["Thinking"] : reply.steps))
        stepIndex = 0
        showsStepper = false
        toastTask?.cancel()
        barToast = .thinking(steps[0])

        let reduce = UIAccessibility.isReduceMotionEnabled
        let every: Double = reply.slow ? Nova.AskMotion.workingStepEvery : 0.7
        var total: Double = reply.slow ? (reduce ? 3.6 : .random(in: 6...10)) : (reduce ? 1.5 : .random(in: 2.0...2.6))
        if !isChatOpen { total = max(total, Nova.AskMotion.dotsDelay + Double(steps.count) * every + 0.2) }

        Task {
            let start = Date.now
            if reply.slow && isChatOpen {
                try? await Task.sleep(for: .seconds(3))
                showsStepper = true
            } else {
                try? await Task.sleep(for: .milliseconds(550))
            }
            while Date.now.timeIntervalSince(start) < total - 0.2 {
                stepIndex = min(stepIndex + 1, steps.count - 1)
                if case .thinking = barToast { barToast = .thinking(steps[stepIndex]) }
                try? await Task.sleep(for: .seconds(min(every, max(0.05, total - Date.now.timeIntervalSince(start)))))
            }
            await land(reply)
        }
    }

    private func land(_ reply: AskReply) async {
        var reply = reply
        switch reply.action {
        case .recall:
            if let t = listings.threads.first(where: { $0.id != threadID }) {
                isBusy = false
                showsStepper = false
                barToast = nil
                open(t, announce: true)
                return
            }
            reply = AskReply(bot: "I don’t have an earlier chat to pick up yet. Tell me what you want in a home, in your own words.")
            reply.surface = true
        case .freshStart(let full):
            if full {
                listings.savedListingIDs = []
                listings.memoryStore.clearCurrent()
            }
        case nil: break
        }

        let highlightedBefore = listings.search.highlighted
        var undo: SearchState.Snapshot?
        if let next = reply.next, next != listings.search {
            var snap: SearchState.Snapshot?
            withAnimation(Nova.Motion.easeOut()) { snap = listings.changeSearch { $0 = next } }
            // Undo is offered on turns that confirmed a change.
            if !reply.tools.isEmpty { undo = snap }
        }
        for t in reply.tools { entries.append(AskEntry(kind: .tool, text: t)) }
        if let w = reply.workDone { entries.append(AskEntry(kind: .work, text: w)) }
        isBusy = false
        showsStepper = false

        // Home cards: the homes this reply pointed at, or the top of the
        // results when it changed the search (the prototype's `bot.homes`).
        var homes: [String] = [], homesTotal = 0
        let hl = listings.search.highlighted
        if case .homes = reply.widget {
        } else if !hl.isEmpty && hl != highlightedBefore {
            homes = Array(hl.prefix(8)); homesTotal = homes.count
        } else if !reply.tools.isEmpty {
            homes = listings.rankedResults.prefix(6).map(\.id); homesTotal = listings.rankedResults.count
        }
        pendingHomes = (homes, homesTotal)

        let tool = reply.tools.first
        guard !reply.bot.isEmpty else {
            if let tool, !isChatOpen { showToast(.done(tool)) } else { barToast = nil }
            suggestions = reply.suggestions.isEmpty ? freshSuggestions() : Array(reply.suggestions.prefix(3))
            syncLog()
            return
        }
        // A reply with a button or widget opens the chat so you can use it
        // (on once Phases 5–6 draw widgets and CTAs).
        if Self.opensChatForAttachments && !isChatOpen && (reply.cta != nil || reply.widget != nil) {
            barToast = nil
            isChatOpen = true
        }
        if isChatOpen {
            barToast = nil
            if tool != nil { try? await Task.sleep(for: .milliseconds(1100)) }
            await streamIntoLog(reply.bot, undo: undo, cta: reply.cta, widget: reply.widget)
        } else {
            if let tool { showToast(.done(tool)) } else { barToast = nil }
            appendBot(reply.bot, undo: undo, streaming: false)
            if tool == nil || reply.surface {
                try? await Task.sleep(for: .milliseconds(tool == nil ? 250 : 1100))
                await streamIntoBubble(reply.bot)
            }
        }
        suggestions = reply.suggestions.isEmpty ? freshSuggestions() : Array(reply.suggestions.prefix(3))
        syncLog()
    }

    // MARK: - Streaming

    @discardableResult
    private func appendBot(_ text: String, undo: SearchState.Snapshot?, streaming: Bool, cta: AskCTA? = nil, widget: AskWidget? = nil) -> UUID {
        var e = AskEntry(kind: .bot, text: text, undo: undo, revealed: streaming ? 0 : nil, cta: cta, widget: widget)
        (e.homes, e.homesTotal) = pendingHomes
        pendingHomes = ([], 0)
        entries.append(e)
        return e.id
    }

    private func streamIntoLog(_ text: String, undo: SearchState.Snapshot?, cta: AskCTA? = nil, widget: AskWidget? = nil) async {
        let id = appendBot(text, undo: undo, streaming: !UIAccessibility.isReduceMotionEnabled, cta: cta, widget: widget)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        isStreaming = true
        let chars = Array(text)
        for i in chars.indices {
            guard let idx = entries.firstIndex(where: { $0.id == id }) else { break }
            entries[idx].revealed = i + 1
            try? await Task.sleep(for: .milliseconds(Self.delay(after: chars[i], next: i + 1 < chars.count ? chars[i + 1] : nil)))
        }
        if let idx = entries.firstIndex(where: { $0.id == id }) { entries[idx].revealed = nil }
        isStreaming = false
    }

    private func streamIntoBubble(_ text: String) async {
        bubbleTask?.cancel()
        bubbleText = text
        guard !UIAccessibility.isReduceMotionEnabled else {
            bubbleRevealed = nil
            scheduleBubbleDismiss(after: 10)
            return
        }
        bubbleRevealed = 0
        let chars = Array(text)
        for i in chars.indices {
            guard bubbleText == text else { return }
            bubbleRevealed = i + 1
            try? await Task.sleep(for: .milliseconds(Self.delay(after: chars[i], next: i + 1 < chars.count ? chars[i + 1] : nil)))
        }
        bubbleRevealed = nil
        scheduleBubbleDismiss(after: 10)
    }

    /// ASK_REDFIN_MOTION pacing: 14ms a character, longer after punctuation.
    private static func delay(after c: Character, next: Character?) -> Int {
        let m = Nova.AskMotion.self
        if c == "\n" { return Int(m.paragraphPause * 1000) }
        if ".!?".contains(c), next == nil || next == " " || next == "\n" { return Int(m.sentencePause * 1000) }
        if c == "," { return Int(m.commaPause * 1000) }
        return Int(m.charDelay * 1000)
    }

    // MARK: - Bar chrome

    private func showToast(_ t: AskBarToast) {
        barToast = t
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.32)) { barToast = nil }
        }
    }

    private func scheduleBubbleDismiss(after seconds: Double) {
        bubbleTask?.cancel()
        bubbleTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(Nova.Motion.easeOut()) { clearBubble() }
        }
    }

    /// Pressing the bubble holds it; letting go restarts a 4s timer.
    func holdBubble(_ holding: Bool) {
        if holding { bubbleTask?.cancel() } else if bubbleText != nil, bubbleRevealed == nil { scheduleBubbleDismiss(after: 4) }
    }

    func clearBubble() {
        bubbleTask?.cancel()
        bubbleText = nil
        bubbleRevealed = nil
    }

    func openChat() {
        clearBubble()
        isComposing = false
        isChatOpen = true
    }

    private func freshSuggestions() -> [String] {
        let asked = Set(entries.filter { $0.kind == .user }.map { $0.text.lowercased() })
        return Array(Self.suggestionPool.filter { !asked.contains($0.lowercased()) }.shuffled().prefix(3))
    }

    // MARK: - Dream Home

    /// Switches to Find (set by ContentView).
    var onShowFind: (() -> Void)?

    /// "Find homes that match": runs the dream home as a search on the map,
    /// narrated in the bar like a typed request.
    func findDreamMatches() {
        guard !isBusy else { return }
        isChatOpen = false
        onShowFind?()
        listings.showListView = false
        listings.dismissOverlay()
        entries.append(AskEntry(kind: .user, text: "Find homes that match my dream home"))
        syncLog()
        let reply = router.findDream(listings.search)
        run(reply, barSteps: reply.steps)
        Task {
            try? await Task.sleep(for: .seconds(1))
            listings.fitListings(listings.filteredListings)
        }
    }

    // MARK: - Handoffs

    func tapCTA(_ cta: AskCTA) {
        if cta.kind == .myHome {
            isChatOpen = false
            onOpenMyHome?()
        } else {
            handoff = cta
        }
    }

    /// A finished handoff (tour booked, prequal done, agent call) is logged
    /// like any other confirmation; a tour also joins your tours.
    func completeHandoff(_ cta: AskCTA, tool: String, reply: String) {
        handoff = nil
        if cta.kind == .tour, let id = cta.listingID {
            listings.search.tours.removeAll { $0.listingID == id }
            listings.search.tours.append(ScheduledTour(listingID: id, day: "Requested", time: ""))
        }
        entries.append(AskEntry(kind: .tool, text: tool))
        entries.append(AskEntry(kind: .bot, text: reply))
        syncLog()
    }

    // MARK: - Feedback

    func thumbsUp(_ id: UUID) {
        setFeedback(id, .up)
        entries.append(AskEntry(kind: .tool, text: "Marked as helpful"))
        syncLog()
    }

    func thumbsDown(_ id: UUID) {
        setFeedback(id, .down)
        let lastBot = entries.last { $0.kind == .bot }
        let canUndo = lastBot?.id == id && lastBot?.undo != nil
        feedbackAsk = (id, canUndo)
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            withAnimation(Nova.Motion.easeOut()) { feedbackAsk = nil }
        }
    }

    private func setFeedback(_ id: UUID, _ f: AskEntry.Feedback) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].feedback = f }
    }

    func dismissFeedback() {
        feedbackTask?.cancel()
        feedbackAsk = nil
    }

    func undoLastChange() {
        guard let ask = feedbackAsk, let entry = entries.first(where: { $0.id == ask.entryID }), let snap = entry.undo else { return }
        dismissFeedback()
        withAnimation(Nova.Motion.easeOut()) { listings.undo(to: snap) }
        entries.append(AskEntry(kind: .tool, text: "Undid the last change"))
        entries.append(AskEntry(kind: .bot, text: "Back to \(AskText.homes(listings.rankedResults.count)). Tell me what you meant and I’ll try again."))
        syncLog()
    }

    func tellUsMore() {
        guard let ask = feedbackAsk else { return }
        dismissFeedback()
        feedbackFormEntry = ask.entryID
    }

    func sendFeedback(reasons: [String], details: String) {
        feedbackFormEntry = nil
        let what = reasons.isEmpty ? "" : ": " + reasons.joined(separator: ", ").lowercased()
        entries.append(AskEntry(kind: .tool, text: "Sent feedback" + what))
        entries.append(AskEntry(kind: .bot, text: "Thanks. I saved this exchange as a test case, so the same mistake is less likely to come back."))
        syncLog()
        thanksToast = true
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(Nova.Motion.easeOut()) { thanksToast = false }
        }
    }

    func copy(_ id: UUID) {
        if let e = entries.first(where: { $0.id == id }) { UIPasteboard.general.string = e.text }
    }

    var lastBotID: UUID? { entries.last { $0.kind == .bot }?.id }

    // MARK: - Threads

    struct ThreadRow: Identifiable {
        let id: String
        let title: String
        let meta: String
        let isCurrent: Bool
        let thread: SearchThread?
    }

    /// The current chat (if you've typed in it) followed by past chats.
    var threadRows: [ThreadRow] {
        var rows: [ThreadRow] = []
        if let first = entries.first(where: { $0.kind == .user })?.text {
            let title = threadTitle ?? (first == Self.introQuery ? "Seattle homes under $1.3M with natural light" : Self.clip(first))
            rows.append(ThreadRow(id: threadID, title: title, meta: "Current chat · " + Self.area(listings.search.locations), isCurrent: true, thread: nil))
        }
        for t in listings.threads where t.id != threadID {
            rows.append(ThreadRow(id: t.id, title: t.title, meta: Self.ago(t.timestamp) + " · " + Self.area(t.memory.search.locations), isCurrent: false, thread: t))
        }
        return rows
    }

    func newChat() {
        guard !isBusy else { return }
        archiveCurrent()
        threadID = "t\(Int(Date.now.timeIntervalSince1970 * 1000))"
        threadTitle = nil
        router.reset()
        entries = [AskEntry(kind: .bot, text: Self.greeting)]
        suggestions = ["Natural light", "Under $900K", "Within a 20 min drive of South Lake Union"]
        syncLog()
    }

    func open(_ thread: SearchThread, announce: Bool = false) {
        guard !isBusy else { return }
        archiveCurrent()
        listings.memoryStore.removeThread(id: thread.id)
        withAnimation(Nova.Motion.easeOut()) { listings.restore(thread.memory) }
        threadID = thread.id
        threadTitle = thread.title
        router.reset()
        entries = [AskEntry(kind: .bot, text: Self.greeting)] + thread.memory.log.map { e in
            AskEntry(kind: e.from == .user ? .user : e.from == .tool ? .tool : .bot, text: e.text)
        }
        let when = Self.ago(thread.timestamp).lowercased()
        if announce {
            entries.append(AskEntry(kind: .tool, text: "Restored your search from \(when)"))
            let s = listings.search
            entries.append(AskEntry(kind: .bot, text: "Welcome back. I kept everything from \(when): \(AskText.homes(listings.rankedResults.count)) in \(AskText.joinAnd(s.locations))\(s.pricePhrase)."))
        } else {
            entries.append(AskEntry(kind: .tool, text: "Opened your chat from \(when)"))
        }
        suggestions = ["Which one fits me best?", "Can I afford the top match?", "Start a fresh search"]
        syncLog()
    }

    private func archiveCurrent() {
        listings.memoryStore.archive(SearchMemory(search: listings.search, favorites: Array(listings.savedListingIDs).sorted(),
                                                  log: listings.askLog, timestamp: .now, title: threadTitle), id: threadID)
    }

    // MARK: - Helpers

    /// Mirrors the conversation into the saved session (user/tool/bot only).
    func syncLog() {
        listings.askLog = entries.dropFirst().compactMap { e in
            switch e.kind {
            case .user: AskLogEntry(from: .user, text: e.text)
            case .tool: AskLogEntry(from: .tool, text: e.text)
            case .bot: e.text.isEmpty ? nil : AskLogEntry(from: .bot, text: e.text)
            case .work: nil
            }
        }.suffix(40).map { $0 }
        listings.saveMemorySoon()
    }

    static func area(_ locations: [String]) -> String {
        AskText.joinAnd(locations.map { $0.replacingOccurrences(of: ", WA", with: "") })
    }

    static func clip(_ s: String) -> String { s.count > 60 ? String(s.prefix(59)) + "…" : s }

    /// "Earlier today", "Yesterday", "Nov 3".
    static func ago(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Earlier today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func mostCommonStreet(_ listings: [Listing]) -> String? {
        var counts: [String: Int] = [:]
        for l in listings {
            let road = l.address
                .replacingOccurrences(of: #"^[\d-]+[A-Z]?\s+"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s+(#|unit|apt|suite)\s*\S*$"#, with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespaces)
            counts[road, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }
}
