import SwiftUI

// Legacy style names used across the app, now backed by native Nova-dressed
// buttons (`Views/Nova/NovaButtons.swift`). New code should use `.nova(...)`.

extension PrimitiveButtonStyle where Self == NovaButtonStyle {
    /// Full-width primary button.
    static var primary: NovaButtonStyle { .nova(.primary, fullWidth: true) }
    /// Full-width secondary button.
    static var secondary: NovaButtonStyle { .nova(.secondary, fullWidth: true) }
    /// Compact primary button.
    static var smallPill: NovaButtonStyle { .nova(.primary, size: .small) }
    /// Compact secondary button.
    static var smallPillOutline: NovaButtonStyle { .nova(.secondary, size: .small) }
}

extension PrimitiveButtonStyle where Self == NovaLinkButtonStyle {
    /// Plain text link (not underlined).
    static var textLink: NovaLinkButtonStyle { NovaLinkButtonStyle(underlined: false) }
}
