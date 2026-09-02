import Foundation
import SwiftUI

nonisolated enum ThinkingState: Equatable, Sendable {
    case none
    case thinking
    case searching

    var label: String {
        switch self {
        case .none: return ""
        case .thinking: return "Thinking"
        case .searching: return "Searching homes"
        }
    }
}

@Observable
@MainActor
class ChatViewModel {
    var threads: [ChatThread] = []
    var activeThreadId: String?
    var inputText: String = ""
    var thinkingState: ThinkingState = .none
    var showThreadSwitcher: Bool = false
    var lastSearchResults: [Listing] = []
    var scrollPositions: [String: String] = [:]
    var carouselScrollPositions: [String: String] = [:]
    var bottomSpacerHeights: [String: CGFloat] = [:]
    var isVoiceModeActive: Bool = false
    var isVoiceMuted: Bool = false
    var voiceTranscriptMessageId: String?
    var voiceScrollToTopId: String?
    var tourDayCurrentStopIndex: Int = 0
    var searchResultsJustArrived: [Listing]?
    var searchFiltersJustArrived: SearchFilters?
    var searchAddNeighborhoodsJustArrived: Bool = false
    var debugSettings: DebugSettings?
    var currentFindFiltersProvider: (() -> SearchFilters)?
    var focusInputOnAppear: Bool = false
    var pendingAttachments: [ChatAttachment] = []

    private let chatService = ChatService()
    private let storageKey = "chatThreads_v2"
    private var streamTask: Task<Void, Never>?
    private var voiceSimTask: Task<Void, Never>?
    private var tourDayTask: Task<Void, Never>?
    private var tourDayAwaitingFirstStopFeedback: Bool = false
    private var tourDayAwaitingFirstStopPhoto: Bool = false

    private let voiceSimPhrases = [
        "I'm looking for a 3 bedroom home near downtown Raleigh with a big backyard"
    ]

    var activeThread: ChatThread? {
        guard let id = activeThreadId else { return nil }
        return threads.first { $0.id == id }
    }

    var activeMessages: [ChatMessage] {
        activeThread?.messages ?? []
    }

    var lastSessionFilters: SearchFilters? {
        for thread in threads where thread.id != activeThreadId {
            if let filters = thread.messages.compactMap({ $0.searchFilters }).last {
                return filters
            }
        }
        return nil
    }

    var isTourDayThread: Bool {
        activeThread?.isTourDay ?? false
    }

    init() {
        UserDefaults.standard.removeObject(forKey: "chatThreads")

        if DemoFixtures.isEnabled {
            // Demo/launch-video override: always open into the fixed seed
            // conversation instead of restoring from UserDefaults. Flip
            // DemoFixtures.isEnabled to false (or delete DemoFixtures.swift)
            // to return to normal persisted-thread behavior.
            threads = [DemoFixtures.seedThread]
            activeThreadId = DemoFixtures.seedThread.id
            return
        }

        loadThreads()
        if threads.isEmpty {
            createNewThread()
        } else {
            activeThreadId = threads.first?.id
        }
    }

    func createNewThread() {
        let welcomeMessage = ChatMessage(
            role: .assistant,
            content: "Hey there! I see you're looking around New York. I can help you find the perfect home \u{2014} just let me know what you're looking for, and I'll take care of the rest."
        )
        let thread = ChatThread(messages: [welcomeMessage])
        threads.insert(thread, at: 0)
        activeThreadId = thread.id
        saveThreads()
    }

    func switchToThread(_ threadId: String) {
        activeThreadId = threadId
        showThreadSwitcher = false
    }

    func deleteThread(_ threadId: String) {
        threads.removeAll { $0.id == threadId }
        if activeThreadId == threadId {
            activeThreadId = threads.first?.id
            if threads.isEmpty { createNewThread() }
        }
        saveThreads()
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = pendingAttachments
        guard !text.isEmpty || !attachments.isEmpty else { return }

        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: attachments.isEmpty ? nil : attachments
        )
        appendMessage(userMessage)
        inputText = ""
        pendingAttachments = []
        if !text.isEmpty {
            updateThreadTitle(from: text)
        } else if !attachments.isEmpty {
            updateThreadTitle(from: attachments.count == 1 ? "Photo" : "Photos")
        }

        if text.lowercased().contains("tour day") {
            requestTourDayNotification()
            return
        }

        if tourDayAwaitingFirstStopPhoto && !attachments.isEmpty {
            tourDayAwaitingFirstStopPhoto = false
            tourDayTask?.cancel()
            tourDayTask = Task { await runTourDayPhotoResponse() }
            return
        }

        let promptForAI = text.isEmpty ? "(shared a photo)" : text
        streamTask?.cancel()
        streamTask = Task { await generateResponse(for: promptForAI) }
    }

    func addPendingAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.append(attachment)
    }

    func addPendingAttachments(_ attachments: [ChatAttachment]) {
        pendingAttachments.append(contentsOf: attachments)
    }

    func removePendingAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    var requestTourDayNotificationHandler: (() -> Void)?

    func requestTourDayNotification() {
        requestTourDayNotificationHandler?()
    }

    func startTourDay() {
        tourDayTask?.cancel()
        streamTask?.cancel()
        thinkingState = .none

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let title = "Tour Day · \(formatter.string(from: Date()))"
        let thread = ChatThread(title: title, messages: [], isTourDay: true)
        threads.insert(thread, at: 0)
        activeThreadId = thread.id
        tourDayCurrentStopIndex = 0
        saveThreads()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        tourDayTask = Task { await runTourDayIntro() }
    }

    private func runTourDayIntro() async {
        try? await Task.sleep(for: .milliseconds(400))
        if Task.isCancelled { return }

        await streamAssistantMessage("Welcome to tour day! I've created a new thread for all things tours. Here's your day at a glance.")
        if Task.isCancelled { return }

        try? await Task.sleep(for: .milliseconds(700))
        if Task.isCancelled { return }

        let routeMsg = ChatMessage(
            role: .assistant,
            content: "I mapped out the most efficient route for your 4 tours today.",
            isStreaming: false,
            tourDayRoute: TourDayData.demoRoute
        )
        appendMessage(routeMsg)
        saveThreads()

        try? await Task.sleep(for: .seconds(2))
        if Task.isCancelled { return }

        guard let firstStop = TourDayData.demoRoute.stops.first else { return }
        tourDayCurrentStopIndex = firstStop.id
        try? await Task.sleep(for: .seconds(2))
        if Task.isCancelled { return }

        await streamAssistantMessage("First stop coming up at \(firstStop.time). Heading to the Tribeca home now.", currentStopId: nil)
        if Task.isCancelled { return }

        let card = ChatMessage(
            role: .assistant,
            content: "",
            tourDayCurrentStopId: firstStop.listingId
        )
        appendMessage(card)
        saveThreads()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        tourDayAwaitingFirstStopFeedback = true

        try? await Task.sleep(for: .seconds(20))
        if Task.isCancelled { return }
        guard tourDayAwaitingFirstStopFeedback else { return }
        await streamAssistantMessage("Tap the {waveform} and let me know what you think of this home!")
    }

    private func runTourDayPhotoPrompt() async {
        try? await Task.sleep(for: .milliseconds(900))
        if Task.isCancelled { return }
        tourDayAwaitingFirstStopPhoto = true
        await streamAssistantMessage("Snap a photo of something that stood out \u{2014} good or bad.")
    }

    private func runTourDayPhotoResponse() async {
        try? await Task.sleep(for: .milliseconds(700))
        if Task.isCancelled { return }
        await streamAssistantMessage("Wow! There are a lot of smart people in this home!")
        if Task.isCancelled { return }
        try? await Task.sleep(for: .seconds(4))
        if Task.isCancelled { return }
        await runTourDayRemainder()
    }

    private func runTourDayRemainder() async {
        let remaining = TourDayData.demoRoute.stops.dropFirst()
        for stop in remaining {
            if Task.isCancelled { return }
            tourDayCurrentStopIndex = stop.id
            try? await Task.sleep(for: .seconds(8))
            if Task.isCancelled { return }

            await streamAssistantMessage(stopTransitionPrompt(for: stop.id), currentStopId: nil)
            if Task.isCancelled { return }

            let card = ChatMessage(
                role: .assistant,
                content: "",
                tourDayCurrentStopId: stop.listingId
            )
            appendMessage(card)
            saveThreads()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        if Task.isCancelled { return }
        tourDayCurrentStopIndex = 0
        try? await Task.sleep(for: .seconds(1))

        let summary = """
        That's a wrap on tour day! Here's a recap of what you loved and didn't — I've passed this along to your agent.

        • 100 Barclay St — Loved the natural light and vaulted ceilings, but the kitchen felt way too small.
        • 88 Greenwich St — Beautiful finishes, but the second bedroom was tight.
        • 55 Hudson Yards — Top pick. The view sold you.
        • 142 W 82nd St — Great space, unsure about the location.
        """
        let summaryMsg = ChatMessage(
            role: .assistant,
            content: summary,
            isTourDaySummary: true
        )
        appendMessage(summaryMsg)
        saveThreads()
    }

    private func stopTransitionPrompt(for stopId: Int) -> String {
        switch stopId {
        case 2: return "On your way to the 2nd tour."
        case 3: return "Heading to tour #3. How did the second one feel?"
        case 4: return "Last stop ahead. What did you think of #3?"
        default: return "Next stop coming up."
        }
    }

    private func streamAssistantMessage(_ text: String, currentStopId: String? = nil) async {
        let msg = ChatMessage(role: .assistant, content: "", isStreaming: true, tourDayCurrentStopId: currentStopId)
        appendMessage(msg)
        await streamText(text, toMessageId: msg.id)
        finalizeMessage(msg.id)
        saveThreads()
    }

    func postFlowConfirmation(_ text: String) {
        Task { await streamAssistantMessage(text) }
    }

    func setFeedback(_ feedback: MessageFeedback, for messageId: String) {
        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }),
              let mi = threads[ti].messages.firstIndex(where: { $0.id == messageId }) else { return }

        if threads[ti].messages[mi].feedback == feedback {
            threads[ti].messages[mi].feedback = nil
        } else {
            threads[ti].messages[mi].feedback = feedback
        }
        saveThreads()
    }

    func activateVoiceMode() {
        isVoiceModeActive = true
        isVoiceMuted = false
        voiceSimTask?.cancel()
        voiceSimTask = Task { await simulateVoiceInput() }
    }

    func deactivateVoiceMode() {
        isVoiceModeActive = false
        isVoiceMuted = false
        voiceSimTask?.cancel()
        voiceSimTask = nil

        if let msgId = voiceTranscriptMessageId {
            finalizeMessage(msgId)
            voiceTranscriptMessageId = nil
        }
    }

    func toggleVoiceMute() {
        isVoiceMuted.toggle()
    }

    private func tourDayVoicePhrase() -> String? {
        guard isTourDayThread, tourDayCurrentStopIndex > 0 else { return nil }
        return TourDayData.voicePhrasesByStop[tourDayCurrentStopIndex]
    }

    private func tourDayAssistantAck() -> String? {
        guard isTourDayThread, tourDayCurrentStopIndex > 0 else { return nil }
        return TourDayData.assistantAcksByStop[tourDayCurrentStopIndex]
    }

    private func simulateVoiceInput() async {
        while isVoiceMuted {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
        }

        try? await Task.sleep(for: .seconds(1.5))
        if Task.isCancelled { return }

        while isVoiceMuted {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
        }

        let phrase = tourDayVoicePhrase() ?? voiceSimPhrases[0]
        let words = phrase.split(separator: " ").map(String.init)

        let userMsg = ChatMessage(role: .user, content: "", isStreaming: true)
        appendMessage(userMsg)
        voiceTranscriptMessageId = userMsg.id
        updateThreadTitle(from: phrase)

        if let threadId = activeThreadId {
            bottomSpacerHeights[threadId] = UIScreen.main.bounds.height
        }
        voiceScrollToTopId = userMsg.id

        var accumulated = ""
        for (i, word) in words.enumerated() {
            if Task.isCancelled { return }
            while isVoiceMuted {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(100))
            }
            accumulated += (i > 0 ? " " : "") + word
            updateMessageContent(userMsg.id, content: accumulated)
            try? await Task.sleep(for: .milliseconds(Int.random(in: 180...350)))
        }

        if Task.isCancelled { return }
        finalizeMessage(userMsg.id)
        voiceTranscriptMessageId = nil

        try? await Task.sleep(for: .milliseconds(600))
        if Task.isCancelled { return }

        if let ack = tourDayAssistantAck() {
            isVoiceModeActive = false
            isVoiceMuted = false
            let wasAwaitingFirstStop = tourDayAwaitingFirstStopFeedback && tourDayCurrentStopIndex == 1
            await streamAssistantMessage(ack)
            if wasAwaitingFirstStop {
                tourDayAwaitingFirstStopFeedback = false
                tourDayTask?.cancel()
                tourDayTask = Task { await runTourDayPhotoPrompt() }
            }
            return
        }

        streamTask?.cancel()
        streamTask = Task { await generateResponse(for: phrase) }
    }

    func stopStreaming() {
        streamTask?.cancel()
        thinkingState = .none

        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        if let last = threads[ti].messages.indices.last,
           threads[ti].messages[last].isStreaming {
            threads[ti].messages[last].isStreaming = false
        }
        saveThreads()
    }

    private func generateResponse(for input: String) async {
        thinkingState = .thinking
        let thinkingStart = ContinuousClock.now

        let response = chatService.matchResponse(for: input)

        try? await Task.sleep(for: .milliseconds(Int.random(in: 500...900)))
        if Task.isCancelled { return }

        let responseText: String
        var searchFilters: SearchFilters?
        var tourReq: TourRequest?
        var mortgageReq: MortgageRequest?
        var isStaleChatWidget = false

        var addNbhd = false
        switch response {
        case .listings(let text, let filters, let add):
            thinkingState = .searching
            try? await Task.sleep(for: .milliseconds(Int.random(in: 300...600)))
            if Task.isCancelled { return }
            responseText = text
            searchFilters = filters
            addNbhd = add

        case .tour(let text, let request):
            responseText = text
            tourReq = request

        case .mortgage(let text, let request):
            responseText = text
            mortgageReq = request

        case .staleChat(let text):
            responseText = text
            isStaleChatWidget = true

        case .fallback(let text):
            responseText = text
        }

        let elapsed = ContinuousClock.now - thinkingStart
        let minimumThinking: Duration = .seconds(2)
        if elapsed < minimumThinking {
            try? await Task.sleep(for: minimumThinking - elapsed)
            if Task.isCancelled { return }
        }

        thinkingState = .none

        let assistantMsg = ChatMessage(role: .assistant, content: "", isStreaming: true)
        appendMessage(assistantMsg)
        let msgId = assistantMsg.id

        await streamText(responseText, toMessageId: msgId)
        if Task.isCancelled { return }

        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }),
              let mi = threads[ti].messages.firstIndex(where: { $0.id == msgId }) else { return }

        if let filters = searchFilters {
            let currentFilters = currentFindFiltersProvider?() ?? SearchFilters()
            let merged = chatService.mergeFilters(current: currentFilters, incoming: filters, addNeighborhoods: addNbhd)
            let results = chatService.searchListings(filters: merged)
            lastSearchResults = results
            threads[ti].messages[mi].searchResults = results.map { $0.id }
            threads[ti].messages[mi].searchFilters = merged
            searchResultsJustArrived = results
            searchFiltersJustArrived = merged
            searchAddNeighborhoodsJustArrived = addNbhd
        }

        if let tourReq {
            threads[ti].messages[mi].tourRequest = tourReq
        }

        if let mortgageReq {
            threads[ti].messages[mi].mortgageRequest = mortgageReq
        }

        if isStaleChatWidget {
            threads[ti].messages[mi].isStaleChatPrompt = true
        }

        finalizeMessage(msgId)
        saveThreads()
    }

    private func streamText(_ text: String, toMessageId msgId: String) async {
        var streamed = ""
        let chars = Array(text)
        var i = 0

        while i < chars.count {
            if Task.isCancelled { return }

            let chunkSize = min(Int.random(in: 1...3), chars.count - i)
            for j in 0..<chunkSize {
                streamed.append(chars[i + j])
            }
            i += chunkSize

            updateMessageContent(msgId, content: streamed)

            let delay = chars[i - 1] == "." || chars[i - 1] == "!" || chars[i - 1] == "?" ? 60 : Int.random(in: 15...35)
            try? await Task.sleep(for: .milliseconds(delay))
        }

        updateMessageContent(msgId, content: text)
    }

    private func appendMessage(_ message: ChatMessage) {
        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        threads[ti].messages.append(message)
        threads[ti].updatedAt = Date()
    }

    private func updateMessageContent(_ messageId: String, content: String) {
        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }),
              let mi = threads[ti].messages.firstIndex(where: { $0.id == messageId }) else { return }
        threads[ti].messages[mi].content = content
    }

    private func finalizeMessage(_ messageId: String) {
        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }),
              let mi = threads[ti].messages.firstIndex(where: { $0.id == messageId }) else { return }
        threads[ti].messages[mi].isStreaming = false
    }

    private func updateThreadTitle(from text: String) {
        guard let ti = threads.firstIndex(where: { $0.id == activeThreadId }) else { return }
        if threads[ti].title == "New Chat" {
            let title = String(text.prefix(40))
            threads[ti].title = title.count < text.count ? title + "…" : title
        }
    }

    private func saveThreads() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadThreads() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ChatThread].self, from: data) else { return }
        threads = decoded
    }
}
