import SwiftUI

struct MortgagePrequalFlowView: View {
    let mortgageRequest: MortgageRequest
    var onCompleted: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    private enum Step: Int {
        case buyingStage, income, downPayment, loanType, creditScore, confirmation
    }

    @State private var step: Step = .buyingStage
    @State private var buyingStage: String?
    @State private var annualIncome: String = ""
    @State private var downPayment: String = ""
    @State private var loanType: String?
    @State private var creditScore: String?

    nonisolated private enum Field { case income, downPayment }
    @FocusState private var focusedField: Field?

    private let buyingStages = ["Signed purchase agreement", "Just researching", "House hunting"]
    private let loanTypes = ["30-year fixed", "15-year fixed", "ARM 5/1", "ARM 7/1"]
    private let creditRanges = ["740+", "700-739", "660-699", "620-659", "Below 620"]

    var body: some View {
        VStack(spacing: 0) {
            if step != .confirmation {
                WizardProgressHeader(progress: progress, onBack: back)
            }

            Group {
                switch step {
                case .buyingStage: buyingStageStep
                case .income: incomeStep
                case .downPayment: downPaymentStep
                case .loanType: loanTypeStep
                case .creditScore: creditScoreStep
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

    private var buyingStageStep: some View {
        FlowStepScaffold(
            title: "Where are you in the home buying process?",
            subtitle: "We've connected you to our partner Rocket Mortgage® to provide a quick estimate.",
            ctaTitle: "Next",
            ctaEnabled: buyingStage != nil,
            onCta: { advance(to: .income) }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(buyingStages, id: \.self) { stage in
                    OptionListButton(title: stage, isSelected: buyingStage == stage) {
                        buyingStage = stage
                    }
                }
            }
        }
    }

    private var incomeStep: some View {
        FlowStepScaffold(
            title: "What's your annual household income?",
            ctaTitle: "Next",
            ctaEnabled: !annualIncome.trimmingCharacters(in: .whitespaces).isEmpty,
            onCta: { advance(to: .downPayment) }
        ) {
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("e.g. 250,000", text: $annualIncome)
                    .keyboardType(.numberPad)
                    .font(Theme.Typography.secondary)
                    .focused($focusedField, equals: .income)
            }
            .frame(minHeight: Theme.ButtonSize.minHeight)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(Theme.Colors.tertiaryBackground)
            .clipShape(.rect(cornerRadius: Theme.Radius.inputField))
        }
    }

    private var downPaymentStep: some View {
        FlowStepScaffold(
            title: "What's your down payment?",
            ctaTitle: "Next",
            ctaEnabled: !downPayment.trimmingCharacters(in: .whitespaces).isEmpty,
            onCta: { advance(to: .loanType) }
        ) {
            HStack {
                Text("$").foregroundStyle(.secondary)
                TextField("e.g. 100,000", text: $downPayment)
                    .keyboardType(.numberPad)
                    .font(Theme.Typography.secondary)
                    .focused($focusedField, equals: .downPayment)
            }
            .frame(minHeight: Theme.ButtonSize.minHeight)
            .padding(.horizontal, Theme.Spacing.sm)
            .background(Theme.Colors.tertiaryBackground)
            .clipShape(.rect(cornerRadius: Theme.Radius.inputField))
        }
    }

    private var loanTypeStep: some View {
        FlowStepScaffold(
            title: "What loan type are you interested in?",
            ctaTitle: "Next",
            ctaEnabled: loanType != nil,
            onCta: { advance(to: .creditScore) }
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(loanTypes, id: \.self) { type in
                    OptionListButton(title: type, isSelected: loanType == type) {
                        loanType = type
                    }
                }
            }
        }
    }

    private var creditScoreStep: some View {
        FlowStepScaffold(
            title: "What's your estimated credit score?",
            ctaTitle: "Get Prequalified",
            ctaEnabled: creditScore != nil,
            onCta: confirm
        ) {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(creditRanges, id: \.self) { range in
                    OptionListButton(title: range, isSelected: creditScore == range) {
                        creditScore = range
                    }
                }
            }
        }
    }

    private var confirmationStep: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Theme.Colors.brandGreen)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Prequalification Complete!")
                    .font(Theme.Typography.sectionTitle)

                if estimatedBudget > 0 {
                    Text(formatCurrency(estimatedBudget))
                        .font(Theme.Typography.largeNumber)
                        .foregroundStyle(Theme.Colors.brandGreen)
                    Text("estimated budget")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(.secondary)
                }

                Text("A Rocket loan officer will reach out to finalize your prequalification.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xs)
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

    // MARK: - Data

    private var estimatedBudget: Int {
        guard let income = Int(annualIncome.replacingOccurrences(of: ",", with: "")),
              let down = Int(downPayment.replacingOccurrences(of: ",", with: "")) else { return 0 }
        return income * 4 + down
    }

    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    private var summaryText: String {
        if estimatedBudget > 0, let loanType {
            return "You're prequalified for up to \(formatCurrency(estimatedBudget)) at a \(loanType) rate — a Rocket loan officer will follow up."
        }
        return "You're prequalified — a Rocket loan officer will follow up to finalize the details."
    }

    private var progress: Double {
        switch step {
        case .buyingStage: return 1.0 / 5
        case .income: return 2.0 / 5
        case .downPayment: return 3.0 / 5
        case .loanType: return 4.0 / 5
        case .creditScore, .confirmation: return 1.0
        }
    }

    // MARK: - Navigation

    private func advance(to newStep: Step) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        step = newStep
    }

    private func back() {
        switch step {
        case .buyingStage: dismiss()
        case .income: step = .buyingStage
        case .downPayment: step = .income
        case .loanType: step = .downPayment
        case .creditScore: step = .loanType
        case .confirmation: break
        }
    }

    private func confirm() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        step = .confirmation
    }
}
