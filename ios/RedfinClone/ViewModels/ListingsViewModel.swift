import Foundation
import SwiftUI
import MapKit
import CoreLocation

nonisolated enum ListingStatus: String, CaseIterable, Sendable, Identifiable {
    case forSale = "For sale"
    case forRent = "For rent"
    case sold = "Sold"
    var id: String { rawValue }
}

@Observable
@MainActor
class ListingsViewModel {
    var debugSettings: DebugSettings?
    var listings: [Listing] = DemoFixtures.isEnabled
        ? HomeCatalog.shared.listings + [DemoFixtures.bookshelfListing]
        : HomeCatalog.shared.listings

    /// The prototype's search: area, filters, criteria, refinements, sort.
    /// Saved as the current session whenever it changes.
    var search = SearchState.initial {
        didSet {
            guard search != oldValue else { return }
            refreshResults()
            saveMemorySoon()
            if search.locations != oldValue.locations { fitLocations(search.locations) }
        }
    }

    /// Ranked results for the current search, recomputed when it changes.
    private(set) var rankedResults: [RankedHome] = []
    /// Homes that get a full price pill on the map (the top 100 by rank); the rest are dots.
    private(set) var pillListingIDs: Set<String> = []
    /// Analysis values for the visible homes, normalized 0–1 for the pin ramp.
    private(set) var analysisPositions: [String: Double] = [:]
    private(set) var analysisRange: (min: Double, max: Double)?

    enum MapStyleOption: String, CaseIterable, Identifiable {
        case streets = "Streets", light = "Light", dark = "Dark"
        var id: String { rawValue }
    }
    var mapStyle: MapStyleOption = .streets
    var isMap3D = false {
        didSet { if isMap3D != oldValue { applyMapPitch() } }
    }

    /// Homes in the selected-home carousel: the tapped home plus its 9 nearest.
    private(set) var carouselListings: [Listing] = []
    /// How many list cards to show (pages of 24).
    var listPageCount = 1
    /// Snapshots taken before each undoable change, newest last.
    private(set) var undoStack: [SearchState.Snapshot] = []
    let memoryStore = SearchMemoryStore()
    /// Conversation log saved alongside the search (filled by the chat in Phase 3).
    var askLog: [AskLogEntry] = []
    private var memorySaveTask: Task<Void, Never>?

    var savedListingIDs: Set<String> = []
    var seenListingIDs: Set<String> = []
    var selectedListing: Listing?
    private(set) var dismissingListing: Listing?
    var isCardVisible: Bool = false
    private var dismissTask: Task<Void, Never>?
    var listingStatus: ListingStatus = .forSale
    var showListView: Bool = false
    var showChat: Bool = false
    var locationName: String = "Seattle"

    /// Bottom edge of the Find tab's floating toolbar (`FindPillBar` or
    /// `FindTopBar`, whichever is active) in `.global` coordinate space, set by
    /// `ContentView`. `FindMapView`'s map controls and the list view sit below
    /// it regardless of how deep they are inside their own safe-area context.
    var topChromeMaxY: CGFloat = 0

    // Legacy filter API used by the current filter sheet, location menu and
    // chat; each one reads and writes `search`.
    var filterMinPrice: Int? {
        get { search.filters.minPrice > 0 ? search.filters.minPrice : nil }
        set { search.filters.minPrice = newValue ?? 0 }
    }
    var filterMaxPrice: Int? {
        get { search.filters.maxPrice > 0 ? search.filters.maxPrice : nil }
        set { search.filters.maxPrice = newValue ?? 0 }
    }
    var filterMinBeds: Int {
        get { search.filters.beds }
        set { search.filters.beds = newValue }
    }
    var filterMinBaths: Int {
        get { Int(search.filters.baths) }
        set { search.filters.baths = Double(newValue) }
    }
    var filterPropertyType: String? {
        get { search.filters.types.first }
        set { search.filters.types = newValue.map { [$0] } ?? [] }
    }
    /// Search areas other than the default "Seattle, WA".
    var filterNeighborhoods: [String] {
        get { search.locations.filter { $0 != SearchRegions.defaultLocation } }
        set {
            let names = newValue.map { SearchRegions.shared.canonicalName($0) }
            search.locations = names.isEmpty ? [SearchRegions.defaultLocation] : names
        }
    }
    var filterIsHotHome: Bool {
        get { search.filters.hotOnly }
        set { search.filters.hotOnly = newValue }
    }
    private var geocodeTask: Task<Void, Never>?
    private let geocoder = CLGeocoder()
    let locationService = LocationService()
    let notificationService = NotificationService()
    private var currentSpan = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    private var currentCenter = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
    private var isAnimatingCamera: Bool = false
    private var cameraAnimationTask: Task<Void, Never>?
    var mapPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321),
        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
    ))

    /// Homes on the map in rank order: the search area filtered by filters,
    /// must-haves, dealbreakers and refinements.
    var filteredListings: [Listing] { rankedResults.map(\.listing) }

    /// How many homes a draft search would show ("Show N homes").
    func count(for draft: SearchState) -> Int { SearchEngine.count(listings, draft) }

    var activeAnalysis: HomeAnalysis? {
        guard let a = search.analysis, a.isOn else { return nil }
        return HomeAnalyses.all[a.key]
    }

    private func refreshResults() {
        rankedResults = SearchEngine.results(listings, search)
        // Pills go to the top 100 by match, whatever the list sort.
        var bestFirst = search
        bestFirst.sort = .match
        let top = search.sort == .match ? rankedResults : SearchEngine.results(listings, bestFirst)
        pillListingIDs = Set(top.prefix(100).map(\.id))

        if let a = activeAnalysis {
            let values = rankedResults.compactMap { r in a.value(r.listing).map { (r.id, $0) } }
            let lo = values.map(\.1).min() ?? 0, hi = values.map(\.1).max() ?? 0
            analysisRange = values.isEmpty ? nil : (lo, hi)
            analysisPositions = Dictionary(uniqueKeysWithValues: values.map { ($0.0, hi > lo ? ($0.1 - lo) / (hi - lo) : 0) })
        } else {
            analysisRange = nil
            analysisPositions = [:]
        }
        listPageCount = 1
        if let selected = selectedListing, !rankedResults.contains(where: { $0.id == selected.id }) {
            dismissOverlay()
        }
    }

    /// Criteria matches for one home under the current search.
    func ranking(for listing: Listing) -> RankedHome {
        let crits = search.scoringCriteria
        let ok = crits.filter { HomeCatalog.has(listing, $0) }
        return RankedHome(listing: listing, matched: ok, missed: crits.filter { !ok.contains($0) })
    }

    var hasActiveFilters: Bool {
        !search.filters.isEmpty || !filterNeighborhoods.isEmpty || !search.criteria.isEmpty
    }

    func clearAllFilters() {
        search.filters = HomeFilters()
        search.locations = [SearchRegions.defaultLocation]
    }

    // MARK: - Undo

    /// Applies a change to the search, saving the prior state for undo.
    /// Returns that snapshot so a chat reply can offer "Undo change".
    @discardableResult
    func changeSearch(_ change: (inout SearchState) -> Void) -> SearchState.Snapshot {
        let before = search.snapshot
        var next = search
        change(&next)
        if next.snapshot != before { undoStack.append(before) }
        search = next
        return before
    }

    func undo(to snapshot: SearchState.Snapshot) {
        search.restore(snapshot)
        if let i = undoStack.lastIndex(of: snapshot) { undoStack.removeSubrange(i...) }
    }

    func undoLast() {
        guard let last = undoStack.popLast() else { return }
        search.restore(last)
    }

    // MARK: - Memory and threads

    var currentMemory: SearchMemory {
        SearchMemory(search: search, favorites: Array(savedListingIDs).sorted(), log: askLog, timestamp: .now)
    }

    var threads: [SearchThread] { memoryStore.loadThreads() }

    /// Restores a saved session's search, saved homes and log.
    func restore(_ memory: SearchMemory) {
        undoStack = []
        search = memory.search
        savedListingIDs = Set(memory.favorites)
        persistSavedListings()
        askLog = memory.log
    }

    /// Archives the current chat and opens a past one.
    func openThread(_ thread: SearchThread) {
        memoryStore.archive(currentMemory)
        memoryStore.removeThread(id: thread.id)
        restore(thread.memory)
    }

    /// "Start fresh": clears the search; `full` also forgets saved homes,
    /// tours and the saved session.
    func startFresh(full: Bool) {
        undoStack = []
        if full {
            search = SearchState()
            savedListingIDs = []
            persistSavedListings()
            memoryStore.clearCurrent()
        } else {
            search.clearSearch()
        }
    }

    func saveMemorySoon() {
        memorySaveTask?.cancel()
        memorySaveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            memoryStore.saveCurrent(currentMemory)
        }
    }

    func applyChatFilters(_ filters: SearchFilters, addNeighborhoods: Bool) {
        if let v = filters.minBeds { filterMinBeds = v }
        if let v = filters.minBaths { filterMinBaths = Int(v) }
        if let v = filters.minPrice { filterMinPrice = v }
        if let v = filters.maxPrice { filterMaxPrice = v }
        if let v = filters.propertyType { filterPropertyType = v }
        if filters.isHotHome == true { filterIsHotHome = true }
        if let nbhds = filters.neighborhoods, !nbhds.isEmpty {
            if addNeighborhoods {
                var combined = filterNeighborhoods
                for n in nbhds where !combined.contains(n) { combined.append(n) }
                filterNeighborhoods = combined
            } else {
                filterNeighborhoods = nbhds
            }
        }
    }

    var currentSearchFilters: SearchFilters {
        SearchFilters(
            minBeds: filterMinBeds > 0 ? filterMinBeds : nil,
            minBaths: filterMinBaths > 0 ? Double(filterMinBaths) : nil,
            minPrice: filterMinPrice,
            maxPrice: filterMaxPrice,
            propertyType: filterPropertyType,
            isHotHome: filterIsHotHome ? true : nil,
            neighborhoods: filterNeighborhoods.isEmpty ? nil : filterNeighborhoods
        )
    }

    func fitNeighborhoods(_ names: [String], sheetFraction: CGFloat = 0) {
        let canonical = names.map { SearchRegions.shared.canonicalName($0) }
        if sheetFraction == 0, SearchRegions.shared.bounds(of: canonical) != nil {
            fitLocations(canonical)
            return
        }
        let regions = names.compactMap { NeighborhoodBounds.region(for: $0) }
        guard !regions.isEmpty else { return }
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        for r in regions {
            minLat = min(minLat, r.center.latitude - r.span.latitudeDelta / 2)
            maxLat = max(maxLat, r.center.latitude + r.span.latitudeDelta / 2)
            minLon = min(minLon, r.center.longitude - r.span.longitudeDelta / 2)
            maxLon = max(maxLon, r.center.longitude + r.span.longitudeDelta / 2)
        }
        let pinLatDelta = max(maxLat - minLat, 0.02)
        let lonDelta = max(maxLon - minLon, 0.02)
        let pinCenterLat = (minLat + maxLat) / 2
        let pinCenterLon = (minLon + maxLon) / 2

        let totalOccluded = sheetFraction + headerFraction
        let visibleFraction = max(1.0 - totalOccluded, 0.15)
        let latDelta = pinLatDelta / visibleFraction
        let bottomOffset = sheetFraction / 2.0 * latDelta
        let topOffset = headerFraction / 2.0 * latDelta
        let centerLat = pinCenterLat - bottomOffset + topOffset

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: pinCenterLon)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        isAnimatingCamera = true
        withAnimation(.easeInOut(duration: 0.6)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
        currentSpan = span
        currentCenter = center
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            isAnimatingCamera = false
        }
    }

    // MARK: - Map camera helpers

    /// Fits the camera to the search areas (falls back to the results).
    func fitLocations(_ names: [String]) {
        guard let b = SearchRegions.shared.bounds(of: names) else {
            fitListings(filteredListings)
            return
        }
        setCamera(minLat: b.minLat, maxLat: b.maxLat, minLon: b.minLng, maxLon: b.maxLng, padding: 1.1, duration: 0.6)
    }

    private func setCamera(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double, padding: Double, duration: Double) {
        let pinLatDelta = max((maxLat - minLat) * padding, 0.01)
        let lonDelta = max((maxLon - minLon) * padding, 0.01)
        let visibleFraction = max(1.0 - headerFraction, 0.15)
        let latDelta = pinLatDelta / visibleFraction
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 + headerFraction / 2 * latDelta, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        isAnimatingCamera = true
        withAnimation(.easeInOut(duration: duration)) {
            mapPosition = cameraPosition(center: center, span: span)
        }
        currentCenter = center
        currentSpan = span
        Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 50))
            isAnimatingCamera = false
        }
    }

    /// A region, or a pitched camera over the same area when 3D is on.
    private func cameraPosition(center: CLLocationCoordinate2D, span: MKCoordinateSpan) -> MapCameraPosition {
        guard isMap3D else { return .region(MKCoordinateRegion(center: center, span: span)) }
        // ~111 km per degree of latitude; distance that shows the span at 45° pitch.
        let distance = span.latitudeDelta * 111_000 * 1.6
        return .camera(MapCamera(centerCoordinate: center, distance: distance, heading: -12, pitch: 45))
    }

    private func applyMapPitch() {
        withAnimation(.easeInOut(duration: 0.6)) {
            mapPosition = cameraPosition(center: currentCenter, span: currentSpan)
        }
    }

    var hotHomes: [Listing] {
        listings.filter { $0.isHotHome }
    }

    var justListed: [Listing] {
        listings.filter { $0.daysOnMarket <= 14 && $0.daysOnMarket > 0 }.sorted { $0.daysOnMarket < $1.daysOnMarket }
    }

    var luxuryHomes: [Listing] {
        listings.filter { $0.price >= Self.luxuryThreshold }.sorted { $0.price > $1.price }.prefix(12).map { $0 }
    }

    /// The catalog tops out at $1.5M, so "luxury" starts at $1.45M.
    static let luxuryThreshold = 1_450_000

    var bestValueHomes: [Listing] {
        listings.filter { $0.sqft > 0 }.sorted { $0.pricePerSqFt < $1.pricePerSqFt }.prefix(8).map { $0 }
    }

    var recentlyReducedHomes: [Listing] {
        listings.filter { $0.daysOnMarket >= 21 }.sorted { $0.daysOnMarket > $1.daysOnMarket }.prefix(8).map { $0 }
    }

    var comingSoonHomes: [Listing] {
        listings.filter { $0.isCompassComingSoon || $0.daysOnMarket == 0 }
    }

    var openHousesThisWeekend: [Listing] {
        let pool = listings.filter { $0.daysOnMarket > 0 }
        return Array(pool.sorted { ($0.id.hashValue ^ 0x5f3759df) < ($1.id.hashValue ^ 0x5f3759df) }.prefix(6))
    }

    var savedListings: [Listing] {
        listings.filter { savedListingIDs.contains($0.id) }
    }

    init() {
        loadSavedListings()
        // Open on the prototype's scenario (Phase 8 types it in as the intro).
        search = .introScenario
        refreshResults()
        // Keep last session aside for "Pick up where I left off" (as the
        // prototype does), and re-seed the demo chats.
        if let previous = memoryStore.loadCurrent() {
            memoryStore.archive(previous)
        }
        memoryStore.seedDemoThreads(listings: HomeCatalog.shared.listings)
    }

    func toggleSaved(_ listing: Listing) {
        if savedListingIDs.contains(listing.id) {
            savedListingIDs.remove(listing.id)
        } else {
            savedListingIDs.insert(listing.id)
        }
        persistSavedListings()
    }

    func isSaved(_ listing: Listing) -> Bool {
        savedListingIDs.contains(listing.id)
    }

    func markSeen(_ listing: Listing) {
        seenListingIDs.insert(listing.id)
    }

    func isSeen(_ listing: Listing) -> Bool {
        seenListingIDs.contains(listing.id)
    }

    func selectListing(_ listing: Listing) {
        if selectedListing?.id == listing.id {
            dismissOverlay()
            return
        }
        let wasCardVisible = isCardVisible && selectedListing != nil
        if !wasCardVisible || !carouselListings.contains(where: { $0.id == listing.id }) {
            carouselListings = nearestListings(to: listing)
        }
        dismissTask?.cancel()
        dismissTask = nil
        dismissingListing = nil
        if wasCardVisible {
            // Swap content in place — no slide animation between pins.
            selectedListing = listing
            markSeen(listing)
            panToListing(listing)
            return
        }
        isCardVisible = false
        selectedListing = listing
        markSeen(listing)
        panToListing(listing)
        Task {
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(debugSettings?.overlayAnimation ?? .spring(response: 0.35, dampingFraction: 0.8)) {
                isCardVisible = true
            }
        }
    }

    /// The tapped home plus its 9 nearest results, nearest first.
    private func nearestListings(to listing: Listing) -> [Listing] {
        let origin = CLLocation(latitude: listing.latitude, longitude: listing.longitude)
        let others = filteredListings
            .filter { $0.id != listing.id }
            .map { ($0, CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(9)
            .map(\.0)
        return [listing] + others
    }

    /// Swiping the carousel selects that home and pans the map to it.
    func selectFromCarousel(_ listing: Listing) {
        guard selectedListing?.id != listing.id else { return }
        selectedListing = listing
        markSeen(listing)
        panToListing(listing)
    }

    private let headerFraction: CGFloat = 0.12

    func fitListings(_ listings: [Listing], sheetFraction: CGFloat = 0) {
        guard !listings.isEmpty else { return }
        if listings.count == 1, let only = listings.first {
            panToListing(only, sheetFraction: sheetFraction)
            return
        }
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        for listing in listings {
            let coord = listing.coordinate
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        let padding = 1.3
        let pinLatDelta = max((maxLat - minLat) * padding, 0.01)
        let lonDelta = max((maxLon - minLon) * padding, 0.01)
        let pinCenterLat = (minLat + maxLat) / 2
        let pinCenterLon = (minLon + maxLon) / 2

        let totalOccluded = sheetFraction + headerFraction
        let visibleFraction = max(1.0 - totalOccluded, 0.15)
        let latDelta = pinLatDelta / visibleFraction
        let bottomOffset = sheetFraction / 2.0 * latDelta
        let topOffset = headerFraction / 2.0 * latDelta
        let centerLat = pinCenterLat - bottomOffset + topOffset

        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: pinCenterLon)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        isAnimatingCamera = true
        withAnimation(.easeInOut(duration: 0.5)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
        currentSpan = span
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            isAnimatingCamera = false
        }
    }

    private let cardOverlayFraction: CGFloat = 0.30

    func panToListing(_ listing: Listing, sheetFraction: CGFloat = 0) {
        let coord = listing.coordinate
        let spanLat = currentSpan.latitudeDelta
        let adjustedLat: Double
        if sheetFraction > 0 {
            let bottomOffset = sheetFraction / 2.0 * spanLat
            let topOffset = headerFraction / 2.0 * spanLat
            adjustedLat = coord.latitude - bottomOffset + topOffset
        } else {
            let cardOffset = cardOverlayFraction / 2.0 * spanLat
            adjustedLat = coord.latitude - cardOffset
        }
        let targetRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: adjustedLat, longitude: coord.longitude),
            span: currentSpan
        )
        let startRegion = MKCoordinateRegion(center: currentCenter, span: currentSpan)
        animateCameraEaseInOut(
            from: startRegion, to: targetRegion,
            duration: DebugSettings.panDuration
        )
    }

    var cardListing: Listing? {
        selectedListing ?? dismissingListing
    }

    func dismissOverlay() {
        dismissTask?.cancel()
        dismissingListing = selectedListing
        selectedListing = nil
        withAnimation(debugSettings?.dismissAnimation ?? .spring(response: 0.35, dampingFraction: 0.8)) {
            isCardVisible = false
        }
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(DebugSettings.dismissSpringResponse))
            guard !Task.isCancelled else { return }
            dismissingListing = nil
        }
    }

    func persistMapRegion(_ region: MKCoordinateRegion) {
        if !isAnimatingCamera {
            currentSpan = region.span
            currentCenter = region.center
            // Capture user pans/zooms into the source-of-truth so the map
            // restores to the same view when FindMapView is recreated
            // (e.g. after switching to list view and back).
            mapPosition = cameraPosition(center: region.center, span: region.span)
        }
        locationService.isTrackingUser = false
    }

    private func animateCameraEaseInOut(from startRegion: MKCoordinateRegion, to endRegion: MKCoordinateRegion, duration: Double) {
        cameraAnimationTask?.cancel()
        isAnimatingCamera = true
        let steps = max(Int(duration * 60), 2)
        let sleepNano = UInt64(duration / Double(steps) * 1_000_000_000)

        cameraAnimationTask = Task {
            for i in 1...steps {
                guard !Task.isCancelled else { break }
                let t = Double(i) / Double(steps)
                let eased = t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
                mapPosition = .region(interpolateRegion(from: startRegion, to: endRegion, t: eased))
                try? await Task.sleep(nanoseconds: sleepNano)
            }
            mapPosition = .region(endRegion)
            currentCenter = endRegion.center
            currentSpan = endRegion.span
            isAnimatingCamera = false
        }
    }

    private func interpolateRegion(from: MKCoordinateRegion, to: MKCoordinateRegion, t: Double) -> MKCoordinateRegion {
        let lat = from.center.latitude + (to.center.latitude - from.center.latitude) * t
        let lon = from.center.longitude + (to.center.longitude - from.center.longitude) * t
        let latD = from.span.latitudeDelta + (to.span.latitudeDelta - from.span.latitudeDelta) * t
        let lonD = from.span.longitudeDelta + (to.span.longitudeDelta - from.span.longitudeDelta) * t
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: max(latD, 0.001), longitudeDelta: max(lonD, 0.001))
        )
    }

    var compassListings: [Listing] {
        listings.filter { $0.isCompassComingSoon }
    }

    func locateUser() {
        locationService.locateUser()
        if locationService.userLocation != nil {
            panToUserLocation()
        }
    }

    func triggerCompassNotificationIfNeeded() {
        guard let userLocation = locationService.userLocation else { return }
        let nearest = compassListings
            .map { (listing: $0, dist: CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: userLocation)) }
            .min { $0.dist < $1.dist }
        if let nearest {
            notificationService.scheduleCompassNotification(nearestListing: nearest.listing)
        }
    }

    func selectNearestCompassListing(to location: CLLocation?) {
        let ref = location ?? locationService.userLocation
        guard let ref else { return }
        let nearest = compassListings
            .map { (listing: $0, dist: CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: ref)) }
            .min { $0.dist < $1.dist }
        if let nearest {
            selectedListing = nearest.listing
            markSeen(nearest.listing)
            fitUserAndListing(nearest.listing)
        }
    }

    func fitUserAndListing(_ listing: Listing) {
        guard let userCoord = locationService.userLocation?.coordinate else {
            panToListing(listing)
            return
        }
        let listingCoord = listing.coordinate
        let minLat = min(userCoord.latitude, listingCoord.latitude)
        let maxLat = max(userCoord.latitude, listingCoord.latitude)
        let minLon = min(userCoord.longitude, listingCoord.longitude)
        let maxLon = max(userCoord.longitude, listingCoord.longitude)
        let padding = 1.05
        let latDelta = max((maxLat - minLat) * padding, 0.004)
        let lonDelta = max((maxLon - minLon) * padding, 0.004)
        let cardOffsetRatio = 0.2
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2 - latDelta * cardOffsetRatio,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        isAnimatingCamera = true
        withAnimation(.easeInOut(duration: 1.0)) {
            mapPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
        currentSpan = span
        Task {
            try? await Task.sleep(for: .milliseconds(1100))
            isAnimatingCamera = false
        }
    }

    func panToUserLocation() {
        guard let location = locationService.userLocation else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            mapPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        }
    }

    func updateLocationName(for region: MKCoordinateRegion) {
        // Launch Demo: keep the search bar pinned to "Seattle" for the
        // recorded video instead of updating as the map pans.
        guard !DemoFixtures.isEnabled else { return }
        geocodeTask?.cancel()
        geocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard !Task.isCancelled else { return }
                if let placemark = placemarks.first {
                    let name = placemark.subLocality
                        ?? placemark.locality
                        ?? placemark.administrativeArea
                        ?? "Seattle"
                    locationName = name
                }
            } catch {
                guard !Task.isCancelled else { return }
                if let nearest = nearestListing(to: region.center) {
                    locationName = nearest.city
                }
            }
        }
    }

    private func nearestListing(to center: CLLocationCoordinate2D) -> Listing? {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return listings.min { a, b in
            let distA = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: centerLocation)
            let distB = CLLocation(latitude: b.latitude, longitude: b.longitude).distance(from: centerLocation)
            return distA < distB
        }
    }

    private func persistSavedListings() {
        let array = Array(savedListingIDs)
        UserDefaults.standard.set(array, forKey: "savedListingIDs")
    }

    private func loadSavedListings() {
        if let array = UserDefaults.standard.stringArray(forKey: "savedListingIDs") {
            savedListingIDs = Set(array)
        }
    }
}
