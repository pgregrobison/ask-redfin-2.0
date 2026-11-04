import SwiftUI

/// Top chrome for the Find tab: a list/map toggle button, a liquid-glass
/// search/location pill with an embedded filter button, and a matching-height
/// liquid-glass "Ask" button — all in one row so they align on the same
/// vertical center. Replaces the old FindPillOverlay (location + home-count
/// pill that expanded into a location/filter menu) and FindView's native
/// leading toolbar button — the filter button here opens FilterSheetView
/// directly instead of that two-step flow.
struct FindTopBar: View {
    @Bindable var viewModel: ListingsViewModel
    let onAskTap: () -> Void

    @State private var showFilterSheet = false

    var body: some View {
        HStack(spacing: 10) {
            listButton
            searchPill
            askButton
        }
        .padding(.horizontal, Theme.Spacing.md)
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private var listButton: some View {
        GlassActionButton(icon: viewModel.showListView ? "map" : "list.bullet") {
            viewModel.dismissOverlay()
            viewModel.showListView.toggle()
        }
    }

    private var searchPill: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image("IconSearch")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.primary)

            Text(viewModel.locationName)
                .font(Theme.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.ButtonSize.circleSize + Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .adaptiveGlass(in: .capsule)
        .overlay(alignment: .trailing) {
            filterButton
                .padding(.trailing, 4)
        }
    }

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            Image("IconFilter")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.primary)
                .padding(Theme.Spacing.xs)
                .background(Theme.Colors.inset, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var askButton: some View {
        Button(action: onAskTap) {
            HStack(spacing: Theme.Spacing.xs) {
                Image("IconAskSparkle")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Ask")
                    .font(Theme.Typography.secondaryBold)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
        .adaptiveGlass(in: .capsule)
    }
}
