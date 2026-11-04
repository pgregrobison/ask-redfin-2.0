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

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if #available(iOS 26.0, *) {
            glassTabBar
        } else {
            legacyTabBar
        }
    }

    @available(iOS 26.0, *)
    private var glassTabBar: some View {
        tabPillContent
            .padding(.horizontal, Theme.Spacing.xs)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.horizontal, Theme.Spacing.md)
    }

    private var legacyTabBar: some View {
        tabPillContent
            .padding(.horizontal, Theme.Spacing.xs)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: Theme.Shadow.overlayColor, radius: Theme.Shadow.overlayRadius, y: Theme.Shadow.overlayY)
            .padding(.horizontal, Theme.Spacing.md)
    }

    private var tabPillContent: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases.filter { $0 != .myRedfin }, id: \.rawValue) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: Theme.Spacing.xxs) {
                        Image(tab.assetName)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Theme.IconSize.tabBar, height: Theme.IconSize.tabBar)
                        Text(tab.title)
                            .font(Theme.Typography.micro)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    }
                    .foregroundStyle(selectedTab == tab ? Theme.Colors.brandRed : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.ButtonSize.tabItemPadding)
                    .background {
                        if selectedTab == tab {
                            Capsule().fill(Theme.Colors.fill)
                        }
                    }
                }
            }
        }
    }
}
