import SwiftUI

/// What you've done with a reply's widget.
struct AskWidgetState: Equatable {
    /// Confirm buttons and the picker's "Plan" are one-shot.
    var used = false
    /// Debrief reactions by listing ID ("loved", "small", ...).
    var reactions: [String: String] = [:]
    /// Inspiration tile you picked.
    var picked: String?
    /// The itinerary is drawn on the map.
    var onMap = false
}

/// Widget taps. Each one runs through the same working state as a typed
/// request, so it reads like a chat turn.
extension AskSession {
    private func index(_ id: UUID) -> Int? { entries.firstIndex { $0.id == id } }

    private func update(_ id: UUID, _ change: (inout AskEntry) -> Void) {
        guard let i = index(id) else { return }
        change(&entries[i])
    }

    // MARK: Homes

    /// Tapping a home card: highlight it, close the chat and show it on the map.
    func openHome(_ id: String) {
        guard let listing = listings.listings.first(where: { $0.id == id }) else { return }
        isChatOpen = false
        listings.showListView = false
        listings.search.highlighted = [id]
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            listings.selectListing(listing)
        }
    }

    /// "Show N homes on map".
    func showOnMap(_ ids: [String]) {
        isChatOpen = false
        listings.showListView = false
        listings.dismissOverlay()
        let xs = listings.filteredListings.filter { ids.contains($0.id) }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            listings.fitListings(xs.isEmpty ? listings.filteredListings : xs)
        }
    }

    // MARK: Watches

    func simulateTrigger(_ w: HomeWatch) {
        guard !isBusy, w.status == .on else { return }
        markWatches(w.id, .hit)
        run(router.triggerWatch(w, listings.search))
    }

    func stopWatching(_ w: HomeWatch) {
        guard !isBusy else { return }
        markWatches(w.id, .off)
        run(router.stopWatch(w, listings.search))
    }

    /// Watch cards show the live status wherever they appear.
    private func markWatches(_ id: String, _ status: HomeWatch.Status) {
        for i in entries.indices {
            if case .watch(var ws) = entries[i].widget, let j = ws.firstIndex(where: { $0.id == id }) {
                ws[j].status = status
                entries[i].widget = .watch(ws)
            }
        }
    }

    func watchStatus(_ w: HomeWatch) -> HomeWatch.Status {
        listings.search.watches.first { $0.id == w.id }?.status ?? w.status
    }

    // MARK: Tour day

    func togglePick(_ entryID: UUID, _ listingID: String) {
        update(entryID) { e in
            guard case .pick(var p) = e.widget, !p.done else { return }
            if p.selected.contains(listingID) { p.selected.remove(listingID) } else { p.selected.insert(listingID) }
            e.widget = .pick(p)
        }
    }

    func setPickDay(_ entryID: UUID, _ day: String) {
        update(entryID) { e in
            guard case .pick(var p) = e.widget, !p.done else { return }
            p.day = day
            e.widget = .pick(p)
        }
    }

    /// "Plan my Saturday (4 stops)": build the route in the picked order.
    func planPicked(_ entryID: UUID) {
        guard !isBusy, let i = index(entryID), case .pick(var p) = entries[i].widget, !p.done, p.selected.count >= 2 else { return }
        p.done = true
        entries[i].widget = .pick(p)
        let ids = p.candidates.filter(p.selected.contains)
        run(router.itineraryReply(router.planDay(ids, day: p.day, start: p.start), listings.search))
    }

    func removeStop(_ entryID: UUID, _ listingID: String) {
        guard !isBusy, let i = index(entryID), case .itinerary(let plan) = entries[i].widget, plan.stops.count > 2 else { return }
        let ids = plan.stops.map(\.listingID).filter { $0 != listingID }
        let name = listings.listings.first { $0.id == listingID }?.address ?? "that stop"
        let onMap = entries[i].widgetState.onMap
        run(router.itineraryReply(router.planDay(ids, day: plan.day, start: plan.start), listings.search, lead: "Removed \(name)."))
        if onMap { listings.tourRoute = router.itinerary?.stops.map(\.listingID) ?? [] }
    }

    /// "Show route on map" / "Hide route".
    func toggleRoute(_ entryID: UUID) {
        guard let i = index(entryID), case .itinerary(let plan) = entries[i].widget else { return }
        let on = !entries[i].widgetState.onMap
        for j in entries.indices { entries[j].widgetState.onMap = false }
        entries[i].widgetState.onMap = on
        listings.tourRoute = on ? plan.stops.map(\.listingID) : []
        if on {
            listings.search.highlighted = plan.stops.map(\.listingID)
            showOnMap(plan.stops.map(\.listingID))
        }
    }

    func requestTours(_ entryID: UUID) {
        guard !isBusy, let i = index(entryID), case .itinerary(var plan) = entries[i].widget, !plan.requested else { return }
        plan.requested = true
        entries[i].widget = .itinerary(plan)
        run(router.requestTours(plan, listings.search))
    }

    func isCurrentItinerary(_ entryID: UUID) -> Bool {
        entries.last { if case .itinerary = $0.widget { return true }; return false }?.id == entryID
    }

    // MARK: Debrief and confirm

    func react(_ entryID: UUID, _ listingID: String, _ kind: String) {
        guard !isBusy, let x = listings.listings.first(where: { $0.id == listingID }) else { return }
        update(entryID) { $0.widgetState.reactions[listingID] = kind }
        run(router.reaction(x, kind, listings.search))
    }

    func confirmMinSqft(_ entryID: UUID, value: Int, accept: Bool) {
        guard !isBusy else { return }
        update(entryID) { $0.widgetState.used = true }
        if accept { run(router.setMinSqft(value, listings.search)) }
    }

    // MARK: Inspiration

    static let inspiration: [(photo: String, key: String, label: String)] = [
        ("ext-craftsman-swing", "craftsman", "Craftsman"), ("ext-modern-white", "modern", "Modern"), ("ext-brick-bungalow", "brick", "Brick"),
        ("ext-shingle-red-door", "shingle", "Shingle"), ("ext-farmhouse", "farmhouse", "Farmhouse"), ("ext-townhouse-row", "townhouse", "Townhouse"),
    ]

    func pickStyle(_ entryID: UUID, _ key: String) {
        guard !isBusy else { return }
        update(entryID) { $0.widgetState.picked = key }
        run(router.styleMatch(key, listings.search))
    }
}
