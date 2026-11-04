import SwiftUI
import MapKit

struct FindMapView: View {
    @Bindable var viewModel: ListingsViewModel
    var zoomNamespace: Namespace.ID
    let onListingTap: (Listing) -> Void
    var showShimmer: Bool = false
    var accessoryMode: Bool = false

    @State private var containerMinY: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.mapPosition) {
                ForEach(viewModel.filteredListings) { listing in
                    Annotation(listing.id, coordinate: listing.coordinate) {
                        Button {
                            viewModel.selectListing(listing)
                        } label: {
                            MapPinView(
                                listing: listing,
                                isSelected: viewModel.selectedListing?.id == listing.id
                            )
                        }
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
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.persistMapRegion(context.region)
                viewModel.updateLocationName(for: context.region)
            }
            .ignoresSafeArea()
            .allowsHitTesting(!showShimmer)

            if showShimmer {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                MapShimmerOverlay()
                    .transition(.opacity)
            }

            Color.clear
                .overlay(alignment: .topTrailing) {
                    MapActionButtons(viewModel: viewModel, containerMinY: containerMinY)
                }
                .allowsHitTesting(!showShimmer)


            if let listing = viewModel.cardListing {
                ListingCardOverlay(
                    listing: listing,
                    isSaved: viewModel.isSaved(listing),
                    onDismiss: { viewModel.dismissOverlay() },
                    onToggleSave: { viewModel.toggleSaved(listing) },
                    onTap: { onListingTap(listing) },
                    zoomNamespace: zoomNamespace,
                    extendsToBottomEdge: !accessoryMode
                )
                .compositingGroup()
                .offset(y: viewModel.isCardVisible ? 0 : UIScreen.main.bounds.height)
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
}

private struct MapActionButtons: View {
    let viewModel: ListingsViewModel
    let containerMinY: CGFloat

    var body: some View {
        GlassActionButtonStack(items: [
            GlassActionButtonItem(icon: "square.3.layers.3d", action: {}),
            GlassActionButtonItem(icon: "hand.draw", action: {}),
            GlassActionButtonItem(icon: viewModel.locationService.isTrackingUser ? "location.fill" : "location", action: {
                viewModel.locateUser()
            })
        ])
        .padding(.trailing, Theme.Spacing.md)
        // Top-align with the Find tab's floating toolbar: that toolbar lives
        // outside this view's NavigationStack, so its safe-area top doesn't
        // match this container's own — sync to its measured position instead
        // of guessing a fixed padding. Can be negative (pulling the stack up
        // past this container's own top-safe-area inset).
        .padding(.top, viewModel.topChromeMinY - containerMinY)
        .animation(nil, value: viewModel.selectedListing != nil)
    }
}
