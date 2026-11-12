import SwiftUI

// MARK: - Button

/// Nova buttons for content (sections, cards, sheet bodies). Glass is
/// reserved for native controls and floating chrome, so these never use it.
///
/// - primary: native `.borderedProminent`, solid Nova near-black capsule
/// - secondary: Nova outline capsule (1.5pt near-black ring)
/// - tertiary: `.borderless`
/// - apply: prominent, tinted Nova green
struct NovaButtonStyle: PrimitiveButtonStyle {
    enum Variant { case primary, secondary, tertiary, apply }

    enum Size {
        case xSmall, small, regular, large

        var controlSize: ControlSize {
            switch self {
            case .xSmall: .mini
            case .small: .small
            case .regular: .regular
            case .large: .large
            }
        }

        /// Nova heights: 32 / 40 / 48 / 56.
        var height: CGFloat {
            switch self {
            case .xSmall: 32
            case .small: 40
            case .regular: 48
            case .large: 56
            }
        }

        var font: Font {
            switch self {
            case .xSmall, .small: Nova.Typography.label14
            default: Nova.Typography.label16
            }
        }
    }

    var variant: Variant = .primary
    var size: Size = .regular
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(size.font)
            .lineLimit(1)
            .frame(maxWidth: fullWidth ? .infinity : nil)

        switch variant {
        case .primary, .apply:
            Button(role: configuration.role, action: configuration.trigger) { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(size.controlSize)
                .tint(variant == .apply ? Nova.Color.green700 : Nova.Color.gray800)
        case .secondary:
            Button(role: configuration.role, action: configuration.trigger) { label }
                .buttonStyle(NovaOutlineButtonStyle(height: size.height))
        case .tertiary:
            Button(role: configuration.role, action: configuration.trigger) { label }
                .buttonStyle(.borderless)
                .controlSize(size.controlSize)
                .foregroundStyle(Nova.Color.text)
        }
    }
}

/// Nova secondary: transparent capsule with a near-black ring and a press wash.
private struct NovaOutlineButtonStyle: ButtonStyle {
    let height: CGFloat
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Nova.Color.text : Nova.Color.gray400)
            .padding(.horizontal, height >= 48 ? 20 : 16)
            .frame(minHeight: height)
            .background(configuration.isPressed ? Nova.Color.overlay : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(isEnabled ? Nova.Color.text : Nova.Color.gray300, lineWidth: 1.5))
            .contentShape(Capsule())
            .animation(Nova.Motion.easeOut(), value: configuration.isPressed)
    }
}

extension PrimitiveButtonStyle where Self == NovaButtonStyle {
    static func nova(
        _ variant: NovaButtonStyle.Variant = .primary,
        size: NovaButtonStyle.Size = .regular,
        fullWidth: Bool = false
    ) -> NovaButtonStyle {
        NovaButtonStyle(variant: variant, size: size, fullWidth: fullWidth)
    }
}

// MARK: - Link

/// Inline text link: a native borderless button in Nova's label type.
struct NovaLinkButtonStyle: PrimitiveButtonStyle {
    var font: Font = Nova.Typography.label14
    var underlined = true

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label.font(font).underline(underlined)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Nova.Color.text)
    }
}

extension PrimitiveButtonStyle where Self == NovaLinkButtonStyle {
    static var novaLink: NovaLinkButtonStyle { NovaLinkButtonStyle() }
}
