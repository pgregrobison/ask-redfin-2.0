import SwiftUI
import MapKit

struct FindPillOverlay: View {
    @Bindable var viewModel: ListingsViewModel
    @Binding var showLocationMenu: Bool
    @State private var showFilterSheet: Bool = false
    @State private var locationSearchService = LocationSearchService()

    var body: some View {
        ZStack(alignment: .top) {
            if showLocationMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeMenu()
                    }
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if showLocationMenu {
                        Button {
                            closeMenu()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: Theme.Spacing.sm + 2, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: Theme.IconSize.smallTap, height: Theme.IconSize.smallTap)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }

                    VStack(alignment: showLocationMenu ? .leading : .center, spacing: 1) {
                        Text(viewModel.locationName)
                            .font(Nova.Typography.label14)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("\(viewModel.filteredListings.count) homes")
                            .font(.nova(11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: showLocationMenu ? .infinity : nil, alignment: showLocationMenu ? .leading : .center)

                    if showLocationMenu {
                        Spacer(minLength: 0)
                    }
                }
                .padding(.horizontal, showLocationMenu ? Theme.Spacing.sm : Theme.Spacing.sm + 2)
                .padding(.vertical, showLocationMenu ? Theme.Spacing.xs + 2 : Theme.Spacing.xxs + 2)
                .frame(minHeight: Theme.ButtonSize.minHeight)

                if showLocationMenu {
                    LocationMenuView(
                        viewModel: viewModel,
                        searchService: locationSearchService,
                        onClose: {
                            closeMenu()
                        },
                        onOpenFilter: {
                            closeMenu()
                            showFilterSheet = true
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: showLocationMenu ? .infinity : nil)
            .adaptiveGlass(in: .rect(cornerRadius: showLocationMenu ? Theme.Radius.xl : 25))
            .clipped()
            .padding(.horizontal, showLocationMenu ? Theme.Spacing.xs : 0)
            .contentShape(.interaction, RoundedRectangle(cornerRadius: showLocationMenu ? 20 : 25))
            .onTapGesture {
                if !showLocationMenu {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        showLocationMenu = true
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: showLocationMenu)
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private func closeMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            showLocationMenu = false
        }
    }
}
