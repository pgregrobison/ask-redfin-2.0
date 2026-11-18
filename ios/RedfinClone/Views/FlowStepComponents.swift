import SwiftUI

// Shared pieces for the tour and Rocket wizards. Each step is its own pushed
// screen in the handoff sheet's NavigationStack, so Back, swipe-back and the
// nav bar are the system's. Content is a native Form; Nova supplies the type,
// icons, colors and the primary button.

/// One wizard step: a large Nova question, Form sections, and a primary
/// button pinned above the home indicator.
struct FlowStepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    /// Fraction of the flow done, shown as a progress bar in the nav bar.
    let progress: Double
    let ctaTitle: String
    let ctaEnabled: Bool
    let onCta: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(Nova.Typography.heading28)
                        .novaHeadingTracking()
                        .foregroundStyle(Nova.Color.text)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(Nova.Typography.body16)
                            .foregroundStyle(Nova.Color.textSubtle)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowBackground(Color.clear)
            }
            content()
        }
        .font(Nova.Typography.body16)
        .tint(Nova.Color.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ProgressView(value: progress)
                    .tint(Nova.Color.text)
                    .frame(width: 120)
                    .accessibilityLabel("Step progress")
                    .accessibilityValue("\(Int((progress * 100).rounded())) percent")
            }
        }
        .safeAreaInset(edge: .bottom) {
            FlowPrimaryButton(title: ctaTitle, enabled: ctaEnabled, action: onCta)
        }
    }
}

/// Single choice from a short list: Settings-style checkmark rows.
struct FlowChoiceSection: View {
    let options: [String]
    @Binding var selection: String?

    var body: some View {
        Section {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    HStack {
                        Text(option).font(Nova.Typography.body16).foregroundStyle(Nova.Color.text)
                        Spacer()
                        if selection == option {
                            NovaIcon("check", size: 20).foregroundStyle(Nova.Color.text)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A currency amount field: "$" then a number pad.
struct FlowAmountField: View {
    let label: String
    let prompt: String
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("$").foregroundStyle(Nova.Color.textSubtle)
            TextField(label, text: $text, prompt: Text(prompt))
                .keyboardType(.numberPad)
                .focused($focused)
                .accessibilityLabel(label)
                .onChange(of: text) { _, new in
                    // Digits only, at most 9, shown with thousands separators.
                    let digits = String(new.filter(\.isNumber).prefix(9))
                    let formatted = Int(digits).map { $0.formatted(.number.grouping(.automatic)) } ?? ""
                    if formatted != new { text = formatted }
                }
        }
        .flowAutofocus($focused)
    }
}

/// The wizard's full-width Nova primary button, on the system bar material.
struct FlowPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.nova(.primary, size: .large, fullWidth: true))
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.bar)
    }
}

/// The finished screen: a green check, the headline, details and Done.
struct FlowConfirmation<Details: View>: View {
    let title: String
    let onDone: () -> Void
    @ViewBuilder let details: () -> Details

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            NovaIcon("check_circle", size: 64)
                .foregroundStyle(Nova.Color.green600)
                .accessibilityHidden(true)
            Text(title)
                .font(Nova.Typography.heading28)
                .novaHeadingTracking()
                .foregroundStyle(Nova.Color.text)
                .multilineTextAlignment(.center)
            details()
                .font(Nova.Typography.body16)
                .foregroundStyle(Nova.Color.textSubtle)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Nova.Color.bgPrimary)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: true)
        .safeAreaInset(edge: .bottom) {
            FlowPrimaryButton(title: "Done", action: onDone)
        }
    }
}

/// The Redfin agent a tour or call is matched with (the chat's Jordan Lee).
struct FlowAgentRow: View {
    var area: String

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.nova(18, .demibold)).foregroundStyle(Nova.Color.bgPrimary)
                .frame(width: 56, height: 56)
                .background(Nova.Color.text, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(AskRouter.agentName).font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                Text("Redfin agent · \(area)").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                Text("4.9 ★ · 128 reviews").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var initials: String {
        AskRouter.agentName.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }
}

extension View {
    /// Focuses a step's first field once the push settles.
    func flowAutofocus(_ focus: FocusState<Bool>.Binding) -> some View {
        task {
            try? await Task.sleep(for: .milliseconds(450))
            focus.wrappedValue = true
        }
    }
}
