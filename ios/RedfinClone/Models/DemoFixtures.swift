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

    // MARK: - Seed conversation

    static let seedThread: ChatThread = {
        let now = Date()

        func message(_ role: ChatRole, _ content: String, searchResults: [String]? = nil, secondsAgo: TimeInterval) -> ChatMessage {
            ChatMessage(
                role: role,
                content: content,
                timestamp: now.addingTimeInterval(-secondsAgo),
                searchResults: searchResults
            )
        }

        var messages: [ChatMessage] = []
        messages.append(message(.user, "Three bedrooms with lots of natural light and a modern feel", secondsAgo: 130))
        messages.append(message(.assistant, "Here are a few 3-bedroom homes with great natural light and a modern feel:", searchResults: ["sc-t1-03", "sc-t2-04", "sc-t1-05", "sc-t2-08", "sc-t2-01"], secondsAgo: 124))
        messages.append(message(.user, "Room for a trampoline?", secondsAgo: 110))
        messages.append(message(.assistant, "Narrowed it down to homes with real yard space for that trampoline:", searchResults: ["sc-t2-04", "sc-t2-08", "sc-t2-01"], secondsAgo: 104))
        messages.append(message(.user, "A pool with a waterfall?", secondsAgo: 90))
        messages.append(message(.assistant, "Getting specific! Here's what's left with pool access nearby:", searchResults: ["sc-t2-04", "sc-t2-08"], secondsAgo: 84))
        messages.append(message(.user, "A secret room hiding behind a bookshelf?", secondsAgo: 70))
        messages.append(message(.assistant, "Okay, this one's a stretch \u{2014} but I found exactly one home with a hidden room behind a bookshelf:", searchResults: [DemoFixtures.bookshelfListing.id], secondsAgo: 64))

        // Property Q&A — mirrors the same beats added on the desktop-side
        // prototype after clicking into the secret-room listing page, so the
        // chat history matches across both. This becomes the new resting
        // point the "Launch Demo" autoplay sequence continues from.
        messages.append(message(.user, "Is this home at risk of flooding?", secondsAgo: 50))
        messages.append(message(.assistant, "Good question \u{2014} 1330 S Jackson St sits in Leschi, a few blocks up from Lake Washington, and isn't in a FEMA-designated flood zone. Worth confirming with a flood certification during your inspection, but there's no flood risk on record for this address.", secondsAgo: 44))
        messages.append(message(.user, "Are there any recent renovations?", secondsAgo: 30))
        messages.append(message(.assistant, "Yes \u{2014} the kitchen and both full bathrooms were updated in 2019 with new cabinetry, quartz countertops, and fixtures. The roof was also replaced in 2021. No major structural work has been reported since.", secondsAgo: 24))
        messages.append(message(.user, "Find me similar homes with a bigger yard, no HOA and in the same school district", secondsAgo: 10))
        messages.append(message(.assistant, "Here are two nearby Capitol Hill homes with more yard space and no HOA:", searchResults: ["sc-t3-04", "sc-t4-01"], secondsAgo: 4))

        // Match the app's normal thread-title convention (ChatViewModel.updateThreadTitle):
        // first 40 characters of the opening message, with a trailing "…" if truncated.
        let firstMessageText = messages[0].content
        let truncatedTitle = String(firstMessageText.prefix(40))
        let title = truncatedTitle.count < firstMessageText.count ? truncatedTitle + "\u{2026}" : truncatedTitle

        return ChatThread(
            id: "demo-seed-thread",
            title: title,
            messages: messages,
            createdAt: now,
            updatedAt: now
        )
    }()
}
