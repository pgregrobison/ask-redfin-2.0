import SwiftUI
import MapKit

struct FindView: View {
    @Bindable var viewModel: ListingsViewModel
    var zoomNamespace: Namespace.ID
    let isActive: Bool
    let onProfileTap: () -> Void
    let onListingTap: (Listing) -> Void
    var showShimmer: Bool = false
    var accessoryMode: Bool = false
    var hideProfileButton: Bool = false
    var hideListToggle: Bool = false
    @Environment(\.askRedfinContext) private var askRedfinContext

    var body: some View {
        Group {
            if viewModel.showListView {
                FindListView(viewModel: viewModel, zoomNamespace: zoomNamespace, onListingTap: onListingTap)
            } else {
                FindMapView(viewModel: viewModel, zoomNamespace: zoomNamespace, onListingTap: onListingTap, showShimmer: showShimmer, accessoryMode: accessoryMode)
            }
        }
        .onAppear { updateContext() }
        .onChange(of: isActive) { _, _ in updateContext() }
        .onChange(of: viewModel.showListView) { _, _ in updateContext() }
        .onChange(of: viewModel.selectedListing?.id) { _, _ in updateContext() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isActive {
                if !hideListToggle {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.dismissOverlay()
                            viewModel.showListView.toggle()
                        } label: {
                            Image(systemName: viewModel.showListView ? "map" : "list.bullet")
                                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        }
                    }
                }
                if viewModel.showListView {
                    ToolbarItem(placement: .topBarTrailing) {
                        sortMenu
                    }
                }
                if !hideProfileButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { onProfileTap() } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        }
                    }
                }
            }
        }
    }

    private func updateContext() {
        guard isActive else { return }
        if viewModel.showListView {
            askRedfinContext.context = .default
        } else {
            askRedfinContext.context = viewModel.selectedListing != nil ? .mapCard : .map
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases, id: \.self) { option in
                Button {
                    viewModel.sortOption = option
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if viewModel.sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
        }
    }

}
