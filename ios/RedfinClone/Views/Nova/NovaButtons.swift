import SwiftUI

// MARK: - Button

/// Native buttons dressed in Nova: Liquid Glass on iOS 26 (bordered styles
/// before), capsule, tinted Nova near-black, WNTL Text. The system supplies
/// the press feel, disabled state and accessibility.
///
/// - primary: `.glassProminent` / `.borderedProminent`
/// - secondary: `.glass` / `.bordered`
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
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label
                .font(size.font)
                .lineLimit(1)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonBorderShape(.capsule)
        .controlSize(size.controlSize)
        .tint(variant == .apply ? Nova.Color.green700 : Nova.Color.gray800)

        switch variant {
        case .primary, .apply:
            if #available(iOS 26.0, *) {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        case .secondary:
            if #available(iOS 26.0, *) {
                button.buttonStyle(.glass).foregroundStyle(Nova.Color.text)
            } else {
                button.buttonStyle(.bordered).foregroundStyle(Nova.Color.text)
            }
        case .tertiary:
            button.buttonStyle(.borderless).foregroundStyle(Nova.Color.text)
        }
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
