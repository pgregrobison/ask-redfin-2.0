import SwiftUI

struct WizardProgressHeader: View {
    let progress: Double
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
                    .background(Theme.Colors.secondaryBackground, in: Circle())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.fill)
                    Capsule()
                        .fill(Theme.Colors.brandGreen)
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }
}

struct OptionListButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.nova(17, .medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(isSelected ? Theme.Colors.brandGreen : Theme.Colors.separator, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct FlowPrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.nova(16, .demibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.ButtonSize.minHeight + 4)
                .background(enabled ? Theme.Colors.brandRed : Color.gray, in: Capsule())
        }
        .disabled(!enabled)
    }
}

struct FlowStepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let ctaTitle: String
    let ctaEnabled: Bool
    let onCta: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(title)
                            .font(Theme.Typography.sectionTitle)
                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.Typography.secondary)
                                .foregroundStyle(.secondary)
                        }
                    }

                    content()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }

            FlowPrimaryButton(title: ctaTitle, enabled: ctaEnabled, action: onCta)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.md)
        }
    }
}
