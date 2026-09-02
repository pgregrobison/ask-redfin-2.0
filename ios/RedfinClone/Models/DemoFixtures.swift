import Foundation

/// Fixed demo/seed conversation for recording the launch video — the app opens
/// straight into this scripted 4-exchange thread instead of a live/persisted
/// one when `isEnabled` is true.
///
/// To turn this off and go back to normal behavior, either flip `isEnabled`
/// to `false` or delete this file (and the two `DemoFixtures.` references in
/// `ChatViewModel.swift`'s `init()`).
enum DemoFixtures {

    /// Master on/off switch for the demo-thread override. See `ChatViewModel.init()`.
    static let isEnabled = true

    // MARK: - Placeholder "secret room" listing (message 4)
    //
    // Every value below is an obvious placeholder to be swapped for the real
    // matching home once the desktop-side prototype has one. Keep these
    // exact values (or a clear 1:1 renamed match) in sync with whatever gets
    // used for the same "secret room" match on the desktop side, so there's
    // only one place to update later, not two.
    static let bookshelfListing = Listing(
        id: "demo-secret-room",
        price: 2_750_000, // PLACEHOLDER_PRICE
        address: "PLACEHOLDER_ADDRESS",
        city: "New York", // PLACEHOLDER_CITY
        neighborhood: "PLACEHOLDER_NEIGHBORHOOD",
        state: "NY", // PLACEHOLDER_STATE
        zip: "10001", // PLACEHOLDER_ZIP
        beds: 4, // PLACEHOLDER_BEDS
        baths: 3.5, // PLACEHOLDER_BATHS
        sqft: 3400, // PLACEHOLDER_SQFT
        latitude: 40.7580, // PLACEHOLDER_LAT
        longitude: -73.9855, // PLACEHOLDER_LNG
        photos: [
            // Not a real URL on purpose — AsyncImage will show its normal
            // failure/placeholder state until this is swapped for a real
            // photo URL or asset name.
            "placeholder_bookshelf_home"
        ],
        description: "PLACEHOLDER_DESCRIPTION — a home with a secret room hidden behind a bookshelf.",
        yearBuilt: 1920, // PLACEHOLDER_YEAR_BUILT
        lotSize: "N/A", // PLACEHOLDER_LOT_SIZE
        propertyType: "Townhouse", // PLACEHOLDER_PROPERTY_TYPE
        isHotHome: true,
        tags: ["Secret room", "Hidden bookshelf door", "PLACEHOLDER_TAG"],
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
        messages.append(message(.user, "Three bedrooms with lots of natural light and a modern feel", secondsAgo: 70))
        messages.append(message(.assistant, "Here are a few 3-bedroom homes with great natural light and a modern feel:", searchResults: ["1", "3", "6", "14", "17"], secondsAgo: 64))
        messages.append(message(.user, "Room for a trampoline?", secondsAgo: 50))
        messages.append(message(.assistant, "Narrowed it down to homes with real yard space for that trampoline:", searchResults: ["1", "6", "17"], secondsAgo: 44))
        messages.append(message(.user, "A pool with a waterfall?", secondsAgo: 30))
        messages.append(message(.assistant, "Getting specific! Here's what's left with pool access nearby:", searchResults: ["1", "17"], secondsAgo: 24))
        messages.append(message(.user, "A secret room hiding behind a bookshelf?", secondsAgo: 10))
        messages.append(message(.assistant, "Okay, this one's a stretch \u{2014} but I found exactly one home with a hidden room behind a bookshelf:", searchResults: [DemoFixtures.bookshelfListing.id], secondsAgo: 4))

        return ChatThread(
            id: "demo-seed-thread",
            title: "New Chat",
            messages: messages,
            createdAt: now,
            updatedAt: now
        )
    }()
}
