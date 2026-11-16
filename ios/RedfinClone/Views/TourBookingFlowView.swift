import SwiftUI

/// Tour request wizard, pushed from the tour handoff sheet. Steps: when →
/// name and number → agent → (matched agent) → requested. Each step is a
/// pushed screen, so Back and swipe-back are the system's.
struct TourBookingFlowView: View {
    let tourRequest: TourRequest
    @Binding var path: NavigationPath
    var onCompleted: (String) -> Void = { _ in }

    nonisolated enum Step: Hashable { case contact, agent, matchedAgent, confirmation }

    @State private var date: Date = Calendar.current.startOfDay(for: .now)
    @State private var timeIndex = 2
    @State private var fullName = ""
    @State private var phone = ""
    @State private var agentChoice: String?
    @FocusState private var nameFocused: Bool

    private let haveAgent = "Yes, I have one"
    private let needAgent = "No, match me with one"

    var body: some View {
        dateTimeStep
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .contact: contactStep
                case .agent: agentStep
                case .matchedAgent: matchedAgentStep
                case .confirmation: confirmationStep
                }
            }
    }

    // MARK: Steps

    private var dateTimeStep: some View {
        FlowStepScaffold(title: "When would you like to tour?", subtitle: tourRequest.address,
                         progress: 1.0 / 3, ctaTitle: "Next", ctaEnabled: true, onCta: { path.append(Step.contact) }) {
            Section {
                DatePicker("Date", selection: $date, in: dateRange, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Nova.Color.brandFixed)
                Picker("Time", selection: $timeIndex) {
                    ForEach(timeSlots.indices, id: \.self) { Text(timeSlots[$0]).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var contactStep: some View {
        FlowStepScaffold(title: "What’s your name and number?", subtitle: "Your agent texts this number to confirm.",
                         progress: 2.0 / 3, ctaTitle: "Next", ctaEnabled: canSubmitContact, onCta: { path.append(Step.agent) }) {
            Section {
                TextField("Full name", text: $fullName)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($nameFocused)
                    .flowAutofocus($nameFocused)
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        }
    }

    private var agentStep: some View {
        FlowStepScaffold(title: "Do you have an agent working with you?", progress: 0.85,
                         ctaTitle: agentChoice == haveAgent ? "Request tour" : "Next", ctaEnabled: agentChoice != nil,
                         onCta: { path.append(agentChoice == haveAgent ? Step.confirmation : Step.matchedAgent) }) {
            FlowChoiceSection(options: [haveAgent, needAgent], selection: $agentChoice)
        }
    }

    private var matchedAgentStep: some View {
        FlowStepScaffold(title: "You’re matched with \(AskRouter.agentFirst)", subtitle: "They’ll meet you at the home and can see your search, so you won’t start over.",
                         progress: 1, ctaTitle: "Request tour", ctaEnabled: true, onCta: { path.append(Step.confirmation) }) {
            Section { FlowAgentRow(area: area) }
        }
    }

    private var confirmationStep: some View {
        FlowConfirmation(title: "Tour requested", onDone: { onCompleted(summaryText) }) {
            VStack(spacing: 4) {
                Text("\(dateLabel) at \(timeLabel)").font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                if let address = tourRequest.address { Text(address) }
                Text(isMatched ? "\(AskRouter.agentName) will text you to confirm." : "We’ll text you to confirm.")
                    .padding(.top, 8)
            }
        }
    }

    // MARK: Data

    private var isMatched: Bool { agentChoice == needAgent }

    private var area: String {
        tourRequest.listingId.flatMap { id in HomeCatalog.shared.listings.first { $0.id == id }?.neighborhood } ?? "Seattle"
    }

    private var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: .now)
        return today...(Calendar.current.date(byAdding: .day, value: 13, to: today) ?? today)
    }

    /// 9:00 AM to 6:00 PM in half hours.
    private var timeSlots: [String] {
        (18...36).compactMap { half in
            Calendar.current.date(bySettingHour: half / 2, minute: half % 2 * 30, second: 0, of: .now)?
                .formatted(date: .omitted, time: .shortened)
        }
    }

    private var dateLabel: String { date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    private var timeLabel: String { timeSlots[timeIndex] }

    private var summaryText: String {
        "Tour requested for \(dateLabel) at \(timeLabel)." + (isMatched ? " You’re matched with \(AskRouter.agentName), who’ll text you to confirm." : "")
    }

    private var canSubmitContact: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty && !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
