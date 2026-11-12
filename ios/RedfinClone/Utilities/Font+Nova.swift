import SwiftUI

/// WNTL Text — Rocket's Nova typeface (bundled in Resources/Fonts, registered
/// via Info.plist `UIAppFonts`). Each weight is its own static file,
/// referenced by exact PostScript name rather than `Font.weight()` trait
/// matching. Nova's weight names: Regular 400, Medium 500, DemiBold 700,
/// Bold 900 ("bold" is the heaviest, not 700).
///
/// Fonts scale with Dynamic Type relative to the text style nearest their
/// point size, so the Nova ramp still honors the user's text size setting.
extension Font {
    enum NovaWeight {
        case regular, medium, demibold, bold

        var postScriptName: String {
            switch self {
            case .regular: "WNTLText-Rg"
            case .medium: "WNTLText-Md"
            case .demibold: "WNTLText-Db"
            case .bold: "WNTLText-Bd"
            }
        }
    }

    static func nova(_ size: CGFloat, _ weight: NovaWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: textStyle(for: size))
    }

    /// Fixed-size variant for chrome that must not grow (map pins, tab bar,
    /// badges inside fixed-size circles).
    static func novaFixed(_ size: CGFloat, _ weight: NovaWeight = .regular) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...: .largeTitle
        case 28..<34: .title
        case 22..<28: .title2
        case 20..<22: .title3
        case 17..<20: .headline
        case 16..<17: .body
        case 15..<16: .subheadline
        case 13..<15: .footnote
        case 12..<13: .caption
        default: .caption2
        }
    }
}
