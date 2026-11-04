import SwiftUI

// MARK: - Button

/// Nova pill button. Primary is near-black and turns brand red while pressed
/// (Nova's signature dark → red); Nova never scales buttons on press.
struct NovaButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary, tertiary, apply }

    enum Size {
        case xSmall, small, regular, large

        var height: CGFloat {
            switch self {
            case .xSmall: 32
            case .small: 40
            case .regular: 48
            case .large: 56
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .xSmall: 12
            case .small: 16
            case .regular: 20
            case .large: 24
            }
        }

        var spacing: CGFloat {
            switch self {
            case .xSmall: 4
            case .small: 6
            default: 8
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

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        HStack(spacing: size.spacing) {
            configuration.label
        }
        .font(size.font)
        .lineLimit(1)
        .foregroundStyle(foreground)
        .padding(.horizontal, size.horizontalPadding)
        .frame(minHeight: size.height)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(background(pressed: pressed), in: Capsule())
        .overlay {
            if variant == .secondary {
                Capsule().strokeBorder(isEnabled ? Nova.Color.text : Nova.Color.gray400, lineWidth: 2)
            }
        }
        .contentShape(Capsule())
        .animation(Nova.Motion.easeOut(), value: pressed)
    }

    private var foreground: Color {
        guard isEnabled else { return Nova.Color.gray400 }
        switch variant {
        case .primary, .apply: return Nova.Color.bgPrimary
        case .secondary, .tertiary: return Nova.Color.text
        }
    }

    private func background(pressed: Bool) -> Color {
        guard isEnabled else {
            return variant == .secondary ? .clear : Nova.Color.gray04Opacity
        }
        switch variant {
        case .primary: return pressed ? Nova.Color.brandFixed : Nova.Color.text
        case .apply: return pressed ? Nova.Color.green600 : Nova.Color.green700
        case .secondary, .tertiary: return pressed ? Nova.Color.overlay : .clear
        }
    }
}

extension ButtonStyle where Self == NovaButtonStyle {
    static func nova(
        _ variant: NovaButtonStyle.Variant = .primary,
        size: NovaButtonStyle.Size = .regular,
        fullWidth: Bool = false
    ) -> NovaButtonStyle {
        NovaButtonStyle(variant: variant, size: size, fullWidth: fullWidth)
    }
}

// MARK: - Icon button

/// 48pt (40pt small) circular icon tap target with a translucent press wash.
struct NovaIconButtonStyle: ButtonStyle {
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        let side: CGFloat = small ? 40 : 48
        configuration.label
            .foregroundStyle(Nova.Color.iconPrimary)
            .frame(width: side, height: side)
            .background(configuration.isPressed ? Nova.Color.overlayStrong : .clear, in: Circle())
            .contentShape(Circle())
            .animation(Nova.Motion.easeOut(), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == NovaIconButtonStyle {
    static var novaIcon: NovaIconButtonStyle { NovaIconButtonStyle() }
    static var novaIconSmall: NovaIconButtonStyle { NovaIconButtonStyle(small: true) }
}

// MARK: - Link

/// Inline text link — weight 500, underlined.
struct NovaLinkButtonStyle: ButtonStyle {
    var font: Font = Nova.Typography.label14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .underline()
            .foregroundStyle(Nova.Color.text)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == NovaLinkButtonStyle {
    static var novaLink: NovaLinkButtonStyle { NovaLinkButtonStyle() }
}
