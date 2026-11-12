import SwiftUI

// MARK: - Card

/// 20pt-radius content container. Default sits on gray-50 with no border;
/// `secondary` is white with a 1pt gray-200 outline.
struct NovaCardModifier: ViewModifier {
    enum Variant { case standard, secondary, dark, brand }

    var variant: Variant = .standard
    var radius: CGFloat = Nova.Radius.card
    var padding: CGFloat? = 24

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding ?? 0)
            .foregroundStyle(variant == .dark || variant == .brand ? Color.white : Nova.Color.text)
            .background(background, in: shape)
            .overlay {
                if variant == .secondary {
                    shape.strokeBorder(Nova.Color.border, lineWidth: 1)
                }
            }
            .clipShape(shape)
    }

    private var background: Color {
        switch variant {
        case .standard: Nova.Color.bgSecondary
        case .secondary: Nova.Color.bgPrimary
        case .dark: Nova.Color.gray800
        case .brand: Nova.Color.brandFixed
        }
    }
}

extension View {
    /// Nova Card surface. Pass `padding: nil` for media cards that manage
    /// their own insets.
    func novaCard(
        _ variant: NovaCardModifier.Variant = .standard,
        radius: CGFloat = Nova.Radius.card,
        padding: CGFloat? = 24
    ) -> some View {
        modifier(NovaCardModifier(variant: variant, radius: radius, padding: padding))
    }
}

// MARK: - Banner

/// Inline feedback row: icon, title, optional subtext.
struct NovaBanner: View {
    enum Variant { case standard, success, warning, info, rocketRed }

    let title: String
    var message: String? = nil
    var icon: String = "info"
    var variant: Variant = .standard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NovaIcon(icon, size: 24)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Nova.Typography.label16)
                if let message {
                    Text(message)
                        .font(Nova.Typography.body14)
                        .opacity(variant == .rocketRed ? 1 : 0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(variant == .rocketRed ? Color.white : Nova.Color.text)
        .padding(16)
        .background(background, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
    }

    private var background: Color {
        switch variant {
        case .standard: Nova.Color.bgSecondary
        case .success: Nova.Color.successBg
        case .warning: Nova.Color.warningBg
        case .info: Nova.Color.infoBg
        case .rocketRed: Nova.Color.brandFixed
        }
    }

    private var iconColor: Color {
        switch variant {
        case .standard: Nova.Color.gray600
        case .success: Nova.Color.successPrimary
        case .warning: Nova.Color.warningPrimary
        case .info: Nova.Color.infoPrimary
        case .rocketRed: .white
        }
    }
}

// MARK: - Glass

extension View {
    /// Nova's frosted surface for chrome that floats over content (pills,
    /// map controls, legend cards). On iOS 26 this is native Liquid Glass —
    /// never a recreated blur; earlier versions fall back to the prototype's
    /// material recipe (white 72%, inset ring, 6% outer ring, elevation 3).
    /// `clear` is the lighter glass for de-emphasized (off) states.
    @ViewBuilder
    func novaGlass<S: Shape>(in shape: S, interactive: Bool = false, clear: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect((clear ? Glass.clear : Glass.regular).interactive(interactive), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(Nova.Color.bgPrimary.opacity(clear ? 0.2 : 0.5), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 1).padding(0.5))
                .overlay(shape.stroke(Nova.Color.gray800.opacity(0.06), lineWidth: 1))
                .novaElevation(.level3)
        }
    }
}

/// Groups neighboring `novaGlass` elements so Liquid Glass renders and
/// morphs them together (a `GlassEffectContainer` on iOS 26).
struct NovaGlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
