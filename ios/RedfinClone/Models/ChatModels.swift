import Foundation

nonisolated enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
    case tool
}

nonisolated enum MessageFeedback: String, Codable, Sendable {
    case thumbsUp
    case thumbsDown
}

nonisolated struct TourRequest: Codable, Sendable {
    let listingId: String?
    let address: String?
}

nonisolated struct TourDayStop: Codable, Sendable, Identifiable, Hashable {
    let id: Int
    let listingId: String
    let time: String
}

nonisolated struct TourDayRoute: Codable, Sendable, Hashable {
    let stops: [TourDayStop]
}

nonisolated struct MortgageRequest: Codable, Sendable {
    let listingId: String?
}

/// Scripted "morph" result for the Request-showing button — used only by the
/// Launch Demo autoplay sequence, in place of the real multi-step tour flow.
nonisolated struct ScriptedTourConfirmation: Codable, Sendable, Hashable {
    let listingId: String
    let dateLabel: String
    let timeLabel: String
    let agentName: String
    let agentPhotoURL: String
}

/// Scripted "morph" result for the Estimate-my-rate button — used only by the
/// Launch Demo autoplay sequence, in place of the real multi-step mortgage flow.
nonisolated struct ScriptedMortgageConfirmation: Codable, Sendable, Hashable {
    let income: Int
    let downPayment: Int
    let loanType: String
    let rateAPR: String
    let expiresLabel: String
}

nonisolated struct SearchFilters: Codable, Sendable {
    var minBeds: Int?
    var maxBeds: Int?
    var minBaths: Double?
    var maxBaths: Double?
    var minPrice: Int?
    var maxPrice: Int?
    var minSqft: Int?
    var maxSqft: Int?
    var propertyType: String?
    var isHotHome: Bool?
    var neighborhoods: [String]?
}

nonisolated struct ChatMessage: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let role: ChatRole
    var content: String
    let timestamp: Date
    var feedback: MessageFeedback?
    var searchResults: [String]?
    var searchFilters: SearchFilters?
    var tourRequest: TourRequest?
    var mortgageRequest: MortgageRequest?
    var scriptedTourConfirmation: ScriptedTourConfirmation?
    var scriptedMortgageConfirmation: ScriptedMortgageConfirmation?
    var isStreaming: Bool
    var isTourRoute: Bool
    var tourDayRoute: TourDayRoute?
    var tourDayCurrentStopId: String?
    var isTourDaySummary: Bool
    var isStaleChatPrompt: Bool
    var toolCalls: [ToolCallRecord]?
    var attachments: [ChatAttachment]?

    init(
        id: String = UUID().uuidString,
        role: ChatRole,
        content: String,
        timestamp: Date = Date(),
        feedback: MessageFeedback? = nil,
        searchResults: [String]? = nil,
        searchFilters: SearchFilters? = nil,
        tourRequest: TourRequest? = nil,
        mortgageRequest: MortgageRequest? = nil,
        scriptedTourConfirmation: ScriptedTourConfirmation? = nil,
        scriptedMortgageConfirmation: ScriptedMortgageConfirmation? = nil,
        isStreaming: Bool = false,
        isTourRoute: Bool = false,
        tourDayRoute: TourDayRoute? = nil,
        tourDayCurrentStopId: String? = nil,
        isTourDaySummary: Bool = false,
        isStaleChatPrompt: Bool = false,
        toolCalls: [ToolCallRecord]? = nil,
        attachments: [ChatAttachment]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.feedback = feedback
        self.searchResults = searchResults
        self.searchFilters = searchFilters
        self.tourRequest = tourRequest
        self.mortgageRequest = mortgageRequest
        self.scriptedTourConfirmation = scriptedTourConfirmation
        self.scriptedMortgageConfirmation = scriptedMortgageConfirmation
        self.isStreaming = isStreaming
        self.isTourRoute = isTourRoute
        self.tourDayRoute = tourDayRoute
        self.tourDayCurrentStopId = tourDayCurrentStopId
        self.isTourDaySummary = isTourDaySummary
        self.isStaleChatPrompt = isStaleChatPrompt
        self.toolCalls = toolCalls
        self.attachments = attachments
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct ToolCallRecord: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let arguments: String
    var result: String?
}

nonisolated struct ChatThread: Identifiable, Codable, Sendable {
    let id: String
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isTourDay: Bool

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        messages: [ChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isTourDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isTourDay = isTourDay
    }
}
