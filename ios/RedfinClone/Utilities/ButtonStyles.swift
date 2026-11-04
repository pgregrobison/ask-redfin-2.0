import SwiftUI

// Legacy style names used across the app, now backed by Nova buttons
// (`Views/Nova/NovaButtons.swift`). New code should use `.nova(...)` directly.

extension ButtonStyle where Self == NovaButtonStyle {
    /// Full-width primary pill.
    static var primary: NovaButtonStyle { .nova(.primary, fullWidth: true) }
    /// Full-width secondary (outlined) pill.
    static var secondary: NovaButtonStyle { .nova(.secondary, fullWidth: true) }
    /// Compact primary pill.
    static var smallPill: NovaButtonStyle { .nova(.primary, size: .small) }
    /// Compact secondary pill.
    static var smallPillOutline: NovaButtonStyle { .nova(.secondary, size: .small) }
}

struct TextLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nova.Typography.label14)
            .foregroundStyle(Nova.Color.text)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }
}
