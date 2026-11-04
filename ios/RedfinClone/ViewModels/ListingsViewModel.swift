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

nonisolated enum SortOption: String, CaseIterable, Sendable {
    case recommended = "Recommended"
    case priceLowToHigh = "Price Low→High"
    case priceHighToLow = "Price High→Low"
    case newest = "Newest"
    case sqft = "Sq Ft"
}

@Observable
@MainActor
class ListingsViewModel {
    var debugSettings: DebugSettings?
    var listings: [Listing] = DemoFixtures.isEnabled ? MockData.listings + [DemoFixtures.bookshelfListing] : MockData.listings
    var savedListingIDs: Set<String> = []
    var seenListingIDs: Set<String> = []
    var selectedListing: Listing?
    private(set) var dismissingListing: Listing?
    var isCardVisible: Bool = false
    private var dismissTask: Task<Void, Never>?
    var sortOption: SortOption = .recommended
    var listingStatus: ListingStatus = .forSale
    var showListView: Bool = false
    var showChat: Bool = false
    var locationName: String = "Seattle"

    /// Top edge of the Find tab's floating toolbar (`FindPillOverlay` or
    /// `FindTopBar`, whichever is active) in `.global` coordinate space, set by
    /// `ContentView`. `FindMapView`'s map control stack reads this to
    /// top-align itself with the toolbar regardless of which style is active
    /// or how deep the map sits inside its own safe-area/nav-bar context.
    var topChromeMinY: CGFloat = 0

    var filterMinPrice: Int? = nil
    var filterMaxPrice: Int? = nil
    var filterMinBeds: Int = 0
    var filterMinBaths: Int = 0
    var filterPropertyType: String? = nil
    var filterNeighborhoods: [String] = []
    var filterIsHotHome: Bool = false
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

    var filteredListings: [Listing] {
        var result = listings
        if let minPrice = filterMinPrice {
            result = result.filter { $0.price >= minPrice }
        }
        if let maxPrice = filterMaxPrice {
            result = result.filter { $0.price <= maxPrice }
        }
        if filterMinBeds > 0 {
            result = result.filter { $0.beds >= filterMinBeds }
        }
        if filterMinBaths > 0 {
            result = result.filter { Int($0.baths) >= filterMinBaths }
        }
        if let propertyType = filterPropertyType {
            result = result.filter { $0.propertyType.lowercased() == propertyType.lowercased() }
        }
        if !filterNeighborhoods.isEmpty {
            let lower = filterNeighborhoods.map { $0.lowercased() }
            result = result.filter { listing in
                let nbhd = listing.neighborhood?.lowercased() ?? ""
                let city = listing.city.lowercased()
                return lower.contains(where: { key in nbhd == key || city == key || nbhd.contains(key) || city.contains(key) })
            }
        }
        if filterIsHotHome {
            result = result.filter { $0.isHotHome }
        }
        return result
    }

    var hasActiveFilters: Bool {
        filterMinPrice != nil || filterMaxPrice != nil || filterMinBeds > 0 || filterMinBaths > 0
            || filterPropertyType != nil || !filterNeighborhoods.isEmpty || filterIsHotHome
    }

    func clearAllFilters() {
        filterMinPrice = nil
        filterMaxPrice = nil
        filterMinBeds = 0
        filterMinBaths = 0
        filterPropertyType = nil
        filterNeighborhoods = []
        filterIsHotHome = false
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

    var sortedListings: [Listing] {
        let base = filteredListings
        switch sortOption {
        case .recommended:
            return base.sorted { a, b in
                if a.isHotHome != b.isHotHome { return a.isHotHome }
                return a.daysOnMarket < b.daysOnMarket
            }
        case .priceLowToHigh:
            return base.sorted { $0.price < $1.price }
        case .priceHighToLow:
            return base.sorted { $0.price > $1.price }
        case .newest:
            return base.sorted { $0.daysOnMarket < $1.daysOnMarket }
        case .sqft:
            return base.sorted { $0.sqft > $1.sqft }
        }
    }

    var hotHomes: [Listing] {
        listings.filter { $0.isHotHome }
    }

    var justListed: [Listing] {
        listings.filter { $0.daysOnMarket <= 14 && $0.daysOnMarket > 0 }.sorted { $0.daysOnMarket < $1.daysOnMarket }
    }

    var luxuryHomes: [Listing] {
        listings.filter { $0.price >= 2_000_000 }.sorted { $0.price > $1.price }
    }

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
            mapPosition = .region(region)
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
