import Foundation

/// Fixed demo/seed conversation for recording the launch video — the app opens
/// straight into this scripted 4-exchange thread instead of a live/persisted
/// one when `isEnabled` is true.
///
/// Controlled by the "Launch Demo" toggle in the debug menu (Debug ▸ Launch
/// Experience). Off = "Original", the app's normal untouched behavior. On =
/// "Launch Demo", everything scripted for the video. The toggle takes effect
/// on next launch, since this is read at app-init time.
enum DemoFixtures {

    /// Master on/off switch for the demo-thread override. Mirrors
    /// `DebugSettings.launchDemoEnabled`, read directly from UserDefaults (not
    /// through `DebugSettings`) because `ChatViewModel`/`ListingsViewModel`
    /// decide this at init time, before `DebugSettings` is wired up. See
    /// `ChatViewModel.init()`.
    static var isEnabled: Bool {
        (UserDefaults.standard.object(forKey: DebugSettings.launchDemoKey) as? Bool) ?? true
    }

    // MARK: - "Secret room" listing (message 4)
    //
    // yearBuilt, lotSize, and description are still placeholders — swap them
    // for the real matching home once the desktop-side prototype has one.
    static let bookshelfListing = Listing(
        id: "demo-secret-room",
        price: 985_000,
        address: "1330 S Jackson St",
        city: "Seattle",
        neighborhood: "Leschi",
        state: "WA",
        zip: "98122",
        beds: 4,
        baths: 3,
        sqft: 2940,
        latitude: 47.6027,
        longitude: -122.2937,
        photos: [HousePhotos.urls[18]] + HousePhotos.interiorURLs, // house19 ("168") + interior shots
        description: "PLACEHOLDER_DESCRIPTION — a home with a secret room hidden behind a bookshelf.",
        yearBuilt: 1920, // PLACEHOLDER_YEAR_BUILT
        lotSize: "N/A", // PLACEHOLDER_LOT_SIZE
        propertyType: "House",
        isHotHome: true,
        tags: ["Secret room"],
        daysOnMarket: 1,
        hoaDues: "N/A",
        buyerAgentFee: "2.5%",
        isListedByRedfin: true
    )
}
