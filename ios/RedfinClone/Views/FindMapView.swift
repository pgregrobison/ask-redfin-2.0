import SwiftUI
import MapKit

struct FindMapView: View {
    @Bindable var viewModel: ListingsViewModel
    var zoomNamespace: Namespace.ID
    let onListingTap: (Listing) -> Void
    var showShimmer: Bool = false
    var accessoryMode: Bool = false

    @State private var containerMinY: CGFloat = 0
    /// When a pin was last tapped; the map's own tap also fires for pin taps.
    @State private var lastPinTap = Date.distantPast

    var body: some View {
        ZStack(alignment: .bottom) {
            map

            if showShimmer {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                MapShimmerOverlay()
                    .transition(.opacity)
            }

            Color.clear
                .overlay(alignment: .topTrailing) {
                    MapControls(viewModel: viewModel)
                        .padding(.trailing, 12)
                        .padding(.top, controlsTop)
                }
                .overlay(alignment: .topLeading) {
                    if let analysis = viewModel.activeAnalysis, let range = viewModel.analysisRange {
                        AnalysisLegendCard(analysis: analysis, range: range)
                            .padding(.leading, 12)
                            .padding(.top, controlsTop)
                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                    }
                }
                .animation(Nova.Motion.easeOut(), value: viewModel.activeAnalysis?.key)
                .allowsHitTesting(!showShimmer)

            if viewModel.cardListing != nil {
                SelectedHomeCarousel(
                    viewModel: viewModel,
                    zoomNamespace: zoomNamespace,
                    onListingTap: onListingTap,
                    extendsToBottomEdge: !accessoryMode
                )
                .offset(y: viewModel.isCardVisible ? 0 : 72)
                .scaleEffect(viewModel.isCardVisible ? 1 : 0.92, anchor: .bottom)
                .opacity(viewModel.isCardVisible ? 1 : 0)
            }
        }
        .onChange(of: viewModel.locationService.userLocation?.coordinate.latitude) { _, _ in
            if viewModel.locationService.isTrackingUser {
                viewModel.panToUserLocation()
                viewModel.triggerCompassNotificationIfNeeded()
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .global).minY
        } action: { minY in
            containerMinY = minY
        }
    }

    /// 12pt below the floating pill bar, which lives outside this view's
    /// safe-area context (can be negative relative to this container).
    private var controlsTop: CGFloat {
        max(viewModel.topChromeMaxY - containerMinY + 12, 12)
    }

    // MARK: Map

    private var map: some View {
        Map(position: $viewModel.mapPosition) {
            if let mask = RegionMask(locations: viewModel.search.locations) {
                MapPolygon(mask.veil)
                    .foregroundStyle(Color(white: 0.075).opacity(0.16))
                ForEach(Array(mask.outlines.enumerated()), id: \.offset) { _, ring in
                    MapPolyline(coordinates: ring)
                        .stroke(Color(white: 0.46), lineWidth: 1)
                }
            }

            ForEach(viewModel.filteredListings) { listing in
                Annotation(listing.id, coordinate: listing.coordinate, anchor: anchor(for: listing)) {
                    Button {
                        lastPinTap = .now
                        viewModel.selectListing(listing)
                    } label: {
                        pin(for: listing)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }

            if let userCoord = viewModel.locationService.userLocation?.coordinate {
                Annotation("My Location", coordinate: userCoord) {
                    UserLocationDot()
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mapStyle)
        .environment(\.colorScheme, viewModel.mapStyle == .dark ? .dark : .light)
        .mapControls { }
        .onTapGesture {
            // Tapping empty map closes the card; ignore the tap a pin just handled.
            Task {
                try? await Task.sleep(for: .milliseconds(80))
                if viewModel.selectedListing != nil, Date.now.timeIntervalSince(lastPinTap) > 0.4 {
                    viewModel.dismissOverlay()
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            viewModel.persistMapRegion(context.region)
            viewModel.updateLocationName(for: context.region)
        }
        .ignoresSafeArea()
        .allowsHitTesting(!showShimmer)
    }

    private var mapStyle: MapStyle {
        let elevation: MapStyle.Elevation = viewModel.isMap3D ? .realistic : .flat
        switch viewModel.mapStyle {
        case .light: return .standard(elevation: elevation, emphasis: .muted, pointsOfInterest: .excludingAll)
        case .streets, .dark: return .standard(elevation: elevation, pointsOfInterest: .excludingAll)
        }
    }

    private func isPill(_ listing: Listing) -> Bool {
        viewModel.pillListingIDs.contains(listing.id)
    }

    private func anchor(for listing: Listing) -> UnitPoint {
        isPill(listing) || viewModel.selectedListing?.id == listing.id ? .bottom : .center
    }

    private func pin(for listing: Listing) -> FindMapPin {
        let position = viewModel.analysisPositions[listing.id]
        return FindMapPin(
            label: listing.formattedPrice,
            isPill: isPill(listing),
            isSelected: viewModel.selectedListing?.id == listing.id,
            isHighlighted: viewModel.search.highlighted.contains(listing.id),
            analysis: position.map { HomeAnalyses.rampColors($0) },
            analysisNoValue: viewModel.activeAnalysis != nil && position == nil
        )
    }
}

// MARK: - Region mask

/// Dims everything outside the search areas: a world-sized polygon with the
/// areas cut out, plus a 1pt outline around each area.
private struct RegionMask {
    let veil: MKPolygon
    let outlines: [[CLLocationCoordinate2D]]

    init?(locations: [String]) {
        let polys = locations.compactMap { SearchRegions.shared.polygons[$0] }
        guard !polys.isEmpty else { return nil }
        var world = [
            CLLocationCoordinate2D(latitude: 48.6, longitude: -123.6), CLLocationCoordinate2D(latitude: 48.6, longitude: -121.0),
            CLLocationCoordinate2D(latitude: 46.6, longitude: -121.0), CLLocationCoordinate2D(latitude: 46.6, longitude: -123.6),
        ]
        let holes = polys.map { p -> MKPolygon in
            var ring = p.ring
            return MKPolygon(coordinates: &ring, count: ring.count)
        }
        veil = MKPolygon(coordinates: &world, count: world.count, interiorPolygons: holes)
        outlines = polys.map { $0.ring + [$0.ring[0]] }
    }
}

// MARK: - Controls

private struct MapControls: View {
    @Bindable var viewModel: ListingsViewModel

    var body: some View {
        VStack(spacing: 8) {
            GlassActionMenuButton(icon: "square.3.layers.3d") {
                Section("Map style") {
                    Picker("Map style", selection: $viewModel.mapStyle) {
                        ForEach(ListingsViewModel.MapStyleOption.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Toggle("3D view", isOn: $viewModel.isMap3D)
            }
            .accessibilityLabel("Map style")

            GlassActionButton(icon: viewModel.locationService.isTrackingUser ? "location.fill" : "location") {
                viewModel.locateUser()
            }
            .accessibilityLabel("Show my location")
        }
        .animation(nil, value: viewModel.selectedListing != nil)
    }
}

// MARK: - Legend

/// Glass key for the active analysis: title, ramp bar, min and max.
private struct AnalysisLegendCard: View {
    let analysis: HomeAnalysis
    let range: (min: Double, max: Double)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                NovaIcon("star_shining", size: 16)
                Text(analysis.title)
                    .font(Nova.Typography.label12)
                    .lineLimit(1)
            }
            Capsule()
                .fill(HomeAnalyses.rampGradient)
                .frame(height: 8)
            HStack(alignment: .top) {
                caption(analysis.format(range.min), analysis.lowCaption, alignment: .leading)
                Spacer()
                caption(analysis.format(range.max), analysis.highCaption, alignment: .trailing)
            }
        }
        .foregroundStyle(Nova.Color.text)
        .padding(12)
        .frame(width: 232)
        .novaGlass(in: RoundedRectangle(cornerRadius: Nova.Radius.field))
    }

    private func caption(_ value: String, _ note: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(value).font(Nova.Typography.label12)
            Text(note).font(Nova.Typography.caption10).foregroundStyle(Nova.Color.textSubtle)
        }
    }
}
