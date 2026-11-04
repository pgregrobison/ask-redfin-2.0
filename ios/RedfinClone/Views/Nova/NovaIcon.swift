import SwiftUI

/// A Nova icon from the bundled sprite (`Assets.xcassets/Nova/<name>`).
/// Icons are 24pt outline glyphs (16pt for dense UI) that tint with the
/// foreground style, so one glyph recolors per context.
struct NovaIcon: View {
    let name: String
    var size: CGFloat = 24

    init(_ name: String, size: CGFloat = 24) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("Nova/\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
