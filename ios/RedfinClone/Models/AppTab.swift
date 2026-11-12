import SwiftUI

nonisolated enum AppTab: Int, CaseIterable, Sendable {
    case find = 0
    case forYou = 1
    case saved = 2
    case myHome = 3
    case myRedfin = 4

    var title: String {
        switch self {
        case .find: "Find"
        case .forYou: "For You"
        case .saved: "Saved"
        case .myHome: "My Home"
        case .myRedfin: "My Redfin"
        }
    }

    /// Custom Blueprint icon asset (Assets.xcassets), replacing the old
    /// SF Symbol icon/selectedIcon pair — one glyph per tab, tinted by
    /// selection state instead of swapping outline/filled variants.
    var assetName: String {
        switch self {
        case .find: "TabFindHomes"
        case .forYou: "TabForYou"
        case .saved: "TabSaved"
        case .myHome: "TabMyHome"
        case .myRedfin: "TabMyRedfin"
        }
    }
}
