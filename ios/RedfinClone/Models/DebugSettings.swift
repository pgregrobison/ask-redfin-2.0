import SwiftUI

nonisolated enum SearchBehavior: String, CaseIterable, Codable, Sendable {
    case `default` = "Default"
    case mapFocus = "Map Focus"
}

nonisolated enum GlobalEntrypoint: String, CaseIterable, Codable, Sendable {
    case appNav = "App nav"
    case accessory = "Accessory"
}

/// Find tab's top chrome + chat entry point. `classic` is the original
/// expanding location/filter pill (`FindPillOverlay`/`LocationMenuView`) plus
/// the bottom `AskRedfinAccessoryBar`. `searchBar` is the newer single-row
/// search bar with an inline Ask button (`FindTopBar`), which replaces the
/// accessory bar entirely since Ask is already reachable from the bar itself.
nonisolated enum FindChromeStyle: String, CaseIterable, Codable, Sendable {
    case classic = "Classic"
    case searchBar = "Search Bar"
}

@Observable
class DebugSettings {
    /// Shared UserDefaults key for the "Launch Demo" toggle. `DemoFixtures.isEnabled`
    /// reads this same key directly (rather than through `DebugSettings`) since the
    /// demo-vs-original decision is made at app-launch/init time, before this class
    /// gets wired up to the rest of the app.
    static let launchDemoKey = "debug_launchDemoEnabled"

    var searchBehavior: SearchBehavior {
        didSet { UserDefaults.standard.set(searchBehavior.rawValue, forKey: "debug_searchBehavior") }
    }

    var globalEntrypoint: GlobalEntrypoint {
        didSet { UserDefaults.standard.set(globalEntrypoint.rawValue, forKey: "debug_globalEntrypoint") }
    }

    var findChromeStyle: FindChromeStyle {
        didSet { UserDefaults.standard.set(findChromeStyle.rawValue, forKey: "debug_findChromeStyle") }
    }

    /// "Launch Demo" — when on, Ask Redfin opens into the fixed seed conversation
    /// (`DemoFixtures.seedThread`) instead of your normal, persisted chat history.
    /// Off = "Original", untouched app behavior. Takes effect on next launch.
    var launchDemoEnabled: Bool {
        didSet { UserDefaults.standard.set(launchDemoEnabled, forKey: Self.launchDemoKey) }
    }

    /// Types the opening Seattle request into the Ask bar on launch, as the
    /// prototype does. Off: the app opens with that search already applied.
    static let playIntroKey = "debug_playIntroQuery"
    var playIntroQuery: Bool {
        didSet { UserDefaults.standard.set(playIntroQuery, forKey: Self.playIntroKey) }
    }

    static let panDuration: Double = 0.35
    static let overlaySpringResponse: Double = 0.35
    static let overlaySpringDamping: Double = 0.8
    static let dismissSpringResponse: Double = 0.35
    static let dismissSpringDamping: Double = 0.8

    var overlayAnimation: Animation {
        .spring(response: Self.overlaySpringResponse, dampingFraction: Self.overlaySpringDamping)
    }

    var dismissAnimation: Animation {
        .spring(response: Self.dismissSpringResponse, dampingFraction: Self.dismissSpringDamping)
    }

    init() {
        let storedBehavior = UserDefaults.standard.string(forKey: "debug_searchBehavior") ?? ""
        self.searchBehavior = SearchBehavior(rawValue: storedBehavior) ?? .mapFocus
        let storedEntry = UserDefaults.standard.string(forKey: "debug_globalEntrypoint") ?? ""
        self.globalEntrypoint = GlobalEntrypoint(rawValue: storedEntry) ?? .accessory
        let storedChrome = UserDefaults.standard.string(forKey: "debug_findChromeStyle") ?? ""
        self.findChromeStyle = FindChromeStyle(rawValue: storedChrome) ?? .classic
        // Defaults to true (Launch Demo) until explicitly toggled, matching the
        // in-progress state of the launch-video work — not just a plain `false` default.
        self.launchDemoEnabled = (UserDefaults.standard.object(forKey: Self.launchDemoKey) as? Bool) ?? true
        self.playIntroQuery = (UserDefaults.standard.object(forKey: Self.playIntroKey) as? Bool) ?? true
    }
}
