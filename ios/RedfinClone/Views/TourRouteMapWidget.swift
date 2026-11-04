import SwiftUI
import MapKit
import UIKit

struct TourRouteMapWidget: View {
    let route: TourDayRoute
    let allListings: [Listing]
    let onStopTap: (Listing) -> Void

    @State private var mapPosition: MapCameraPosition
    @State private var showFullMap: Bool = false
    @State private var hasAppeared: Bool = false

    init(route: TourDayRoute, allListings: [Listing], onStopTap: @escaping (Listing) -> Void) {
        self.route = route
        self.allListings = allListings
        self.onStopTap = onStopTap
        let coords = route.stops.compactMap { stop in
            allListings.first(where: { $0.id == stop.listingId })?.coordinate
        }
        let region = Self.regionFitting(coords)
        _mapPosition = State(initialValue: .region(region))
    }

    private static func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.74, longitude: -73.99),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.04),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.04)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private var stopsWithListings: [(stop: TourDayStop, listing: Listing)] {
        route.stops.compactMap { stop in
            guard let listing = allListings.first(where: { $0.id == stop.listingId }) else { return nil }
            return (stop, listing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            mapView
                .frame(height: 200)
                .contentShape(Rectangle())
                .onTapGesture { showFullMap = true }
            stopList
            directionsButton
        }
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: Theme.Radius.widget))
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                hasAppeared = true
            }
        }
        .fullScreenCover(isPresented: $showFullMap) {
            FullScreenRouteMap(stopsWithListings: stopsWithListings, isPresented: $showFullMap)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill")
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's tour route")
                    .font(Theme.Typography.headline)
                Text("\(route.stops.count) stops • optimized order")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.md)
    }

    private var mapView: some View {
        Map(position: $mapPosition, interactionModes: []) {
            ForEach(stopsWithListings, id: \.stop.id) { item in
                Annotation(item.listing.address, coordinate: item.listing.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.brandRed)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        Text("\(item.stop.id)")
                            .font(.nova(11, .demibold))
                            .foregroundStyle(.white)
                    }
                }
                .annotationTitles(.hidden)
            }

            MapPolyline(coordinates: stopsWithListings.map { $0.listing.coordinate })
                .stroke(Theme.Colors.brandRed, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    private var stopList: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(stopsWithListings, id: \.stop.id) { item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onStopTap(item.listing)
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.brandRed)
                                .frame(width: 22, height: 22)
                            Text("\(item.stop.id)")
                                .font(.nova(11, .demibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.listing.address)
                                .font(.nova(15, .demibold))
                                .foregroundStyle(.primary)
                            Text(item.listing.neighborhood ?? item.listing.city)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(item.stop.time)
                            .font(.nova(12, .demibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
    }

    private var directionsButton: some View {
        Menu {
            Button {
                openInAppleMaps()
            } label: {
                Label("Apple Maps", systemImage: "map")
            }
            Button {
                openInGoogleMaps()
            } label: {
                Label("Google Maps", systemImage: "globe")
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                Text("Open directions")
            }
        }
        .buttonStyle(.primary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }

    private func openInAppleMaps() {
        let items = stopsWithListings.map { item -> MKMapItem in
            let placemark = MKPlacemark(coordinate: item.listing.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = item.listing.address
            return mapItem
        }
        guard !items.isEmpty else { return }
        MKMapItem.openMaps(with: items, launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps() {
        let stops = stopsWithListings.map { $0.listing.coordinate }
        guard let last = stops.last, stops.count >= 1 else { return }
        let waypoints = stops.dropLast().map { "\($0.latitude),\($0.longitude)" }.joined(separator: "|")
        let dest = "\(last.latitude),\(last.longitude)"
        var components = URLComponents(string: "https://www.google.com/maps/dir/")
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: dest),
            URLQueryItem(name: "travelmode", value: "driving"),
            URLQueryItem(name: "waypoints", value: waypoints)
        ]
        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }
}

private struct FullScreenRouteMap: View {
    let stopsWithListings: [(stop: TourDayStop, listing: Listing)]
    @Binding var isPresented: Bool

    @State private var mapPosition: MapCameraPosition

    init(stopsWithListings: [(stop: TourDayStop, listing: Listing)], isPresented: Binding<Bool>) {
        self.stopsWithListings = stopsWithListings
        _isPresented = isPresented
        let coords = stopsWithListings.map { $0.listing.coordinate }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.4, 0.04),
            longitudeDelta: max(((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.4, 0.04)
        )
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(center: center, span: span)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $mapPosition) {
                ForEach(stopsWithListings, id: \.stop.id) { item in
                    Annotation(item.listing.address, coordinate: item.listing.coordinate) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.brandRed)
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            Text("\(item.stop.id)")
                                .font(.nova(17, .demibold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                MapPolyline(coordinates: stopsWithListings.map { $0.listing.coordinate })
                    .stroke(Theme.Colors.brandRed, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.md)
        }
    }
}
