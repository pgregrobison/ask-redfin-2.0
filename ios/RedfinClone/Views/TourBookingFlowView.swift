import SwiftUI

private struct TimeSlot {
    let label: String
    let hour: Int
    let minute: Int
}

struct TourBookingFlowView: View {
    let tourRequest: TourRequest
    var onCompleted: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    private enum Step: Int {
        case dateTime, contact, agent, matchedAgent, confirmation
    }

    @State private var step: Step = .dateTime
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedTimeIndex: Int = 2
    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var hasAgent: Bool?

    nonisolated private enum Field { case name, phone }
    @FocusState private var focusedField: Field?

    private let matchedAgentName = "Jordan Kim"
    private let matchedAgentPhotoURL = "https://i.pravatar.cc/200?img=68"
    private let matchedAgentRating = "4.9 ★ (128 reviews)"

    var body: some View {
        VStack(spacing: 0) {
            if step != .confirmation {
                WizardProgressHeader(progress: progress, onBack: back)
            }

            Group {
                switch step {
                case .dateTime: dateTimeStep
                case .contact: contactStep
                case .agent: agentStep
                case .matchedAgent: matchedAgentStep
                case .confirmation: confirmationStep
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .animation(.snappy(duration: 0.3), value: step)
    }

    // MARK: - Steps

    private var dateTimeStep: some View {
        FlowStepScaffold(
            title: "When would you like to tour?",
            subtitle: tourRequest.address,
            ctaTitle: "Next",
            ctaEnabled: true,
            onCta: { advance(to: .contact) }
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Pick a date")
                        .font(Theme.Typography.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(nextDates, id: \.self) { date in
                                dateCard(date)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Pick a time")
                        .font(Theme.Typography.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(timeSlots.indices, id: \.self) { index in
                                timeCard(index)
                            }
                        }
                    }
                }
            }
        }
    }

    private var contactStep: some View {
        FlowStepScaffold(
            title: "What's your name and number?",
            ctaTitle: "Next",
            ctaEnabled: canSubmitContact,
            onCta: { advance(to: .agent) }
        ) {
            VStack(spacing: Theme.Spacing.sm + 2) {
                TextField("Full name", text: $fullName)
                    .font(Theme.Typography.secondary)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .phone }
                    .frame(minHeight: Theme.ButtonSize.minHeight)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(.rect(cornerRadius: Theme.Radius.inputField))

                TextField("Phone number", text: $phone)
                    .font(Theme.Typography.secondary)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .phone)
                    .onSubmit { focusedField = nil }
                    .frame(minHeight: Theme.ButtonSize.minHeight)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(.rect(cornerRadius: Theme.Radius.inputField))
            }
        }
    }

    private var agentStep: some View {
        FlowStepScaffold(
            title: "Do you have an agent working with you?",
            ctaTitle: "Next",
            ctaEnabled: hasAgent != nil,
            onCta: {
                if hasAgent == true {
                    confirm()
                } else {
                    advance(to: .matchedAgent)
                }
            }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                OptionListButton(title: "Yes, I have one", isSelected: hasAgent == true) {
                    hasAgent = true
                }
                OptionListButton(title: "No, match me with one", isSelected: hasAgent == false) {
                    hasAgent = false
                }
            }
        }
    }

    private var matchedAgentStep: some View {
        FlowStepScaffold(
            title: "You're matched!",
            ctaTitle: "Request Tour",
            ctaEnabled: true,
            onCta: confirm
        ) {
            matchedAgentCard
        }
    }

    private var confirmationStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.Colors.brandGreen)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Tour Requested")
                    .font(.inter(22, .bold))
                Text("\(dateLabel) at \(timeLabel)")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(.secondary)
                if hasAgent == false {
                    Text("You're matched with \(matchedAgentName).")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            FlowPrimaryButton(title: "Done") {
                onCompleted(summaryText)
                dismiss()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cards

    private func dateCard(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.inter(11, .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? Theme.Colors.brandGreen : .secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(Theme.Typography.largeNumber)
                    .foregroundStyle(selected ? Theme.Colors.brandGreen : .primary)
                Text(date.formatted(.dateTime.month(.abbreviated)))
                    .font(.inter(11, .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? Theme.Colors.brandGreen : .secondary)
            }
            .frame(width: 84, height: 96)
            .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .stroke(selected ? Theme.Colors.brandGreen : Theme.Colors.separator, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func timeCard(_ index: Int) -> some View {
        let slot = timeSlots[index]
        let selected = index == selectedTimeIndex
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedTimeIndex = index
        } label: {
            Text(slot.label)
                .font(.inter(15, .semibold))
                .foregroundStyle(selected ? Theme.Colors.brandGreen : .primary)
                .frame(width: 92, height: 52)
                .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(selected ? Theme.Colors.brandGreen : Theme.Colors.separator, lineWidth: selected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var matchedAgentCard: some View {
        HStack(spacing: Theme.Spacing.sm) {
            AsyncImage(url: URL(string: matchedAgentPhotoURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                case .empty:
                    ZStack {
                        Color(.tertiarySystemFill)
                        ProgressView()
                    }
                @unknown default:
                    Color(.tertiarySystemFill)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(matchedAgentName)
                    .font(Theme.Typography.secondaryBold)
                Text(matchedAgentRating)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(tourRequest.address.map { "Local expert near \($0)" } ?? "Local expert in the area")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.inputField))
    }

    // MARK: - Data

    private var nextDates: [Date] {
        (0..<14).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date()))
        }
    }

    private var timeSlots: [TimeSlot] {
        var slots: [TimeSlot] = []
        for hour in 9...18 {
            for minute in [0, 30] {
                if hour == 18 && minute == 30 { continue }
                let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
                slots.append(TimeSlot(label: date.formatted(date: .omitted, time: .shortened), hour: hour, minute: minute))
            }
        }
        return slots
    }

    private var dateLabel: String {
        selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var timeLabel: String {
        timeSlots[selectedTimeIndex].label
    }

    private var summaryText: String {
        var text = "Tour requested for \(dateLabel) at \(timeLabel)."
        if hasAgent == false {
            text += " You're matched with \(matchedAgentName)."
        }
        return text
    }

    private var canSubmitContact: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var progress: Double {
        switch step {
        case .dateTime: return 1.0 / 3
        case .contact: return 2.0 / 3
        case .agent, .matchedAgent: return 1.0
        case .confirmation: return 1.0
        }
    }

    // MARK: - Navigation

    private func advance(to newStep: Step) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        step = newStep
    }

    private func back() {
        switch step {
        case .dateTime: dismiss()
        case .contact: step = .dateTime
        case .agent: step = .contact
        case .matchedAgent: step = .agent
        case .confirmation: break
        }
    }

    private func confirm() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        step = .confirmation
    }
}
