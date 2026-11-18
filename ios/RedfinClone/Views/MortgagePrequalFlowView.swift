import SwiftUI

/// Rocket Mortgage prequal wizard, pushed from the Rocket handoff sheet.
/// Steps: buying stage → income → down payment → loan type → credit →
/// estimate. Each step is a pushed screen with the system Back.
struct MortgagePrequalFlowView: View {
    let mortgageRequest: MortgageRequest
    @Binding var path: NavigationPath
    var onCompleted: (String) -> Void = { _ in }

    nonisolated enum Step: Hashable { case income, downPayment, loanType, creditScore, confirmation }

    @State private var buyingStage: String?
    @State private var annualIncome = ""
    @State private var downPayment = ""
    @State private var loanType: String?
    @State private var creditScore: String?

    private let buyingStages = ["House hunting", "Signed a purchase agreement", "Just researching"]
    private let loanTypes = ["30-year fixed", "15-year fixed", "5/1 ARM", "7/1 ARM"]
    private let creditRanges = ["740+", "700–739", "660–699", "620–659", "Below 620"]

    var body: some View {
        buyingStageStep
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .income: incomeStep
                case .downPayment: downPaymentStep
                case .loanType: loanTypeStep
                case .creditScore: creditScoreStep
                case .confirmation: confirmationStep
                }
            }
    }

    // MARK: Steps

    private var buyingStageStep: some View {
        FlowStepScaffold(title: "Where are you in the home buying process?",
                         subtitle: "Rocket Mortgage uses this for a quick estimate. Your Redfin search stays here.",
                         progress: 1.0 / 5, ctaTitle: "Next", ctaEnabled: buyingStage != nil, onCta: { path.append(Step.income) }) {
            FlowChoiceSection(options: buyingStages, selection: $buyingStage)
        }
    }

    private var incomeStep: some View {
        FlowStepScaffold(title: "What’s your annual household income?", subtitle: "Before taxes, for everyone on the loan.",
                         progress: 2.0 / 5, ctaTitle: "Next", ctaEnabled: amount(annualIncome) > 0, onCta: { path.append(Step.downPayment) }) {
            Section { FlowAmountField(label: "Annual household income", prompt: "e.g. 250,000", text: $annualIncome) }
        }
    }

    private var downPaymentStep: some View {
        FlowStepScaffold(title: "How much can you put down?",
                         progress: 3.0 / 5, ctaTitle: "Next", ctaEnabled: amount(downPayment) > 0, onCta: { path.append(Step.loanType) }) {
            Section { FlowAmountField(label: "Down payment", prompt: "e.g. 100,000", text: $downPayment) }
        }
    }

    private var loanTypeStep: some View {
        FlowStepScaffold(title: "Which loan are you interested in?",
                         progress: 4.0 / 5, ctaTitle: "Next", ctaEnabled: loanType != nil, onCta: { path.append(Step.creditScore) }) {
            FlowChoiceSection(options: loanTypes, selection: $loanType)
        }
    }

    private var creditScoreStep: some View {
        FlowStepScaffold(title: "What’s your estimated credit score?", subtitle: "An estimate is fine. This won’t affect your credit.",
                         progress: 1, ctaTitle: "Get my estimate", ctaEnabled: creditScore != nil, onCta: { path.append(Step.confirmation) }) {
            FlowChoiceSection(options: creditRanges, selection: $creditScore)
        }
    }

    private var confirmationStep: some View {
        FlowConfirmation(title: "You’re prequalified", onDone: { onCompleted(summaryText) }) {
            VStack(spacing: 4) {
                Text(currency(estimatedBudget))
                    .font(Nova.Typography.heading36)
                    .novaHeadingTracking()
                    .foregroundStyle(Nova.Color.text)
                Text("estimated budget" + (loanType.map { " · \($0)" } ?? ""))
                Text("A Rocket loan officer will reach out to finalize your prequalification.")
                    .padding(.top, 12)
            }
        }
    }

    // MARK: Data

    private func amount(_ s: String) -> Int { Int(s.filter(\.isNumber)) ?? 0 }

    private var estimatedBudget: Int { amount(annualIncome) * 4 + amount(downPayment) }

    private func currency(_ v: Int) -> String { v.formatted(.currency(code: "USD").precision(.fractionLength(0))) }

    private var summaryText: String {
        "You’re prequalified for up to \(currency(estimatedBudget))" + (loanType.map { " with a \($0) loan" } ?? "") + ". A Rocket loan officer will follow up to finalize the details."
    }
}
