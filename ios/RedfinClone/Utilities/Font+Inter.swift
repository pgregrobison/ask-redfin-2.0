import SwiftUI

/// Inter (bundled in Resources/Fonts, registered via Info.plist `UIAppFonts`)
/// — used app-wide in place of the system font to match the desktop
/// prototype. Each weight is its own static file, referenced by exact
/// PostScript name rather than `Font.weight()`/`.bold()` trait matching,
/// since several of the static weights don't share a common family name at
/// the OS font-matching level.
extension Font {
    enum InterWeight {
        case light, regular, medium, semibold, bold, black

        var postScriptName: String {
            switch self {
            case .light: "Inter-Light"
            case .regular: "Inter-Regular"
            case .medium: "Inter-Medium"
            case .semibold: "Inter-SemiBold"
            case .bold: "Inter-Bold"
            case .black: "Inter-Black"
            }
        }
    }

    static func inter(_ size: CGFloat, _ weight: InterWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }
}
