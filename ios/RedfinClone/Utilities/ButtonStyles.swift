import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.invertedPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.ButtonSize.verticalPadding)
            .background(Color.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.secondaryBold)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.ButtonSize.verticalPadding)
            .background(
                Capsule()
                    .stroke(Theme.Colors.separator, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct TextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.secondaryBold)
            .foregroundStyle(.primary)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct SmallPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(15, .semibold))
            .foregroundStyle(Theme.Colors.invertedPrimary)
            .padding(.horizontal, Theme.ButtonSize.pillHorizontalPadding)
            .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
            .background(Color.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

struct SmallPillOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(15, .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, Theme.ButtonSize.pillHorizontalPadding)
            .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
            .background(
                Capsule()
                    .stroke(Theme.Colors.separator, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct ActionCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.ButtonSize.iconSize, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
            .overlay(
                Circle()
                    .stroke(Theme.Colors.separator, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

struct IconCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.ButtonSize.iconSize, weight: .bold))
            .foregroundStyle(Theme.Colors.invertedPrimary)
            .frame(width: Theme.ButtonSize.circleSize, height: Theme.ButtonSize.circleSize)
            .background(Color.primary)
            .clipShape(Circle())
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }
}

extension ButtonStyle where Self == SmallPillButtonStyle {
    static var smallPill: SmallPillButtonStyle { SmallPillButtonStyle() }
}

extension ButtonStyle where Self == SmallPillOutlineButtonStyle {
    static var smallPillOutline: SmallPillOutlineButtonStyle { SmallPillOutlineButtonStyle() }
}

extension ButtonStyle where Self == ActionCircleButtonStyle {
    static var actionCircle: ActionCircleButtonStyle { ActionCircleButtonStyle() }
}

extension ButtonStyle where Self == IconCircleButtonStyle {
    static var iconCircle: IconCircleButtonStyle { IconCircleButtonStyle() }
}
