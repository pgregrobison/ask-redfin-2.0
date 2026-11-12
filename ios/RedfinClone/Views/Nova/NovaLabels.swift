import SwiftUI

// MARK: - Chip

/// 32pt filter/selection pill (44pt when `touch`). Default is a translucent
/// wash; `outline` is white with a hairline; `selected` is near-black.
struct NovaChip: View {
    enum Style { case standard, outline }

    let title: String
    var icon: String? = nil
    var isSelected = false
    var style: Style = .standard
    var touch = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    NovaIcon(icon, size: 16)
                }
                Text(title)
                    .font(Nova.Typography.label14)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: touch ? 44 : 32)
            .foregroundStyle(isSelected ? Nova.Color.bgPrimary : Nova.Color.text)
            .background(background, in: Capsule())
            .overlay {
                if style == .outline && !isSelected {
                    Capsule().strokeBorder(Nova.Color.border, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(NovaPressWashStyle(shape: Capsule()))
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var background: Color {
        if isSelected { return Nova.Color.text }
        return style == .outline ? Nova.Color.bgPrimary : Nova.Color.overlay
    }
}

/// Darkens any surface with Nova's translucent press wash instead of scaling.
struct NovaPressWashStyle<S: Shape>: ButtonStyle {
    var shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                shape.fill(Nova.Color.overlay).opacity(configuration.isPressed ? 1 : 0)
            }
            .animation(Nova.Motion.easeOut(), value: configuration.isPressed)
    }
}

// MARK: - Tag

/// 6pt-radius status label.
struct NovaTag: View {
    enum Variant { case standard, slate, rocket, success, info, warning, outline }
    enum Size { case regular, medium, small }

    let title: String
    var variant: Variant = .standard
    var size: Size = .regular
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { NovaIcon(icon, size: 16) }
            Text(title)
                .font(Nova.Typography.label14)
                .tracking(0.1)
                .lineLimit(1)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .foregroundStyle(colors.text)
        .background(colors.background, in: RoundedRectangle(cornerRadius: Nova.Radius.tag))
        .overlay {
            if variant == .outline {
                RoundedRectangle(cornerRadius: Nova.Radius.tag).strokeBorder(Nova.Color.text, lineWidth: 1)
            }
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .regular: 8
        case .medium: 6
        case .small: 4
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .regular: 4
        case .medium: 2
        case .small: 0
        }
    }

    private var colors: (background: Color, text: Color) {
        switch variant {
        case .standard: (Nova.Color.overlay, Nova.Color.text)
        case .slate: (Nova.Color.gray800, .white)
        case .rocket: (Nova.Color.brandFixed, .white)
        case .success: (Nova.Color.green50, Nova.Color.green700)
        case .info: (Nova.Color.blue50, Nova.Color.blue700)
        case .warning: (Nova.Color.yellow50, Nova.Color.yellow700)
        case .outline: (Nova.Color.bgPrimary, Nova.Color.text)
        }
    }
}

// MARK: - Badge

/// 22pt pill indicator for counts and notifications.
struct NovaBadge: View {
    enum Variant { case brand, slate, success, info, warning }

    let text: String
    var variant: Variant = .brand

    var body: some View {
        Text(text)
            .font(.novaFixed(12, .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch variant {
        case .brand: Nova.Color.brandFixed
        case .slate: Nova.Color.gray800
        case .success: Nova.Color.green700
        case .info: Nova.Color.blue600
        case .warning: Nova.Color.yellow700
        }
    }
}
