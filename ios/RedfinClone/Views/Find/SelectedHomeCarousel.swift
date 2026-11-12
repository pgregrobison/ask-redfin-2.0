import SwiftUI

/// Pages through the tapped home and its 9 nearest neighbors. Swiping
/// selects that home and pans the map to it; tapping opens the detail page.
struct SelectedHomeCarousel: View {
    @Bindable var viewModel: ListingsViewModel
    var zoomNamespace: Namespace.ID
    let onListingTap: (Listing) -> Void
    var extendsToBottomEdge = true

    @State private var scrolledID: String?
    @State private var settleTask: Task<Void, Never>?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(viewModel.carouselListings) { listing in
                    SelectedHomeCard(
                        listing: listing,
                        isSaved: viewModel.isSaved(listing),
                        onTap: { onListingTap(listing) },
                        onClose: { viewModel.dismissOverlay() },
                        onToggleSave: { viewModel.toggleSaved(listing) }
                    )
                    .matchedTransitionSource(id: listing.id, in: zoomNamespace)
                    .containerRelativeFrame(.horizontal)
                    .id(listing.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrolledID)
        .contentMargins(.horizontal, 8, for: .scrollContent)
        .scrollClipDisabled()
        // A horizontal scroll view is greedy vertically; hug the cards.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
        .onAppear { scrolledID = viewModel.cardListing?.id }
        .onChange(of: viewModel.selectedListing?.id) { _, id in
            // Tapping another pin jumps the carousel to it.
            guard let id, id != scrolledID else { return }
            withAnimation(Nova.Motion.easeOut()) { scrolledID = id }
        }
        .onChange(of: scrolledID) { _, id in
            settleTask?.cancel()
            settleTask = Task {
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled, let id, let listing = viewModel.carouselListings.first(where: { $0.id == id }) else { return }
                viewModel.selectFromCarousel(listing)
            }
        }
        .sensoryFeedback(.selection, trigger: scrolledID)
    }
}

/// The map's home card: photo with badges and close, price with share and
/// save, facts and address.
private struct SelectedHomeCard: View {
    let listing: Listing
    let isSaved: Bool
    let onTap: () -> Void
    let onClose: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                ListingPhoto(url: listing.photos.first)
                    .frame(height: 238)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) { badges.padding(12) }
            .overlay(alignment: .topTrailing) {
                GlassActionButton(icon: "close", action: onClose, nova: true)
                    .padding(8)
                    .accessibilityLabel("Close")
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(listing.formattedFullPrice)
                        .font(.nova(18, .demibold))
                        .foregroundStyle(Nova.Color.text)
                    Spacer()
                    ShareLink(item: listing.shareText) {
                        NovaIcon("ios_share", size: 24)
                            .foregroundStyle(Nova.Color.text)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Share")
                    SaveHeartButton(isSaved: isSaved, action: onToggleSave)
                }
                .frame(height: 36)
                HomeFactsLine(listing: listing)
                Text(listing.fullAddress)
                    .font(Nova.Typography.caption12)
                    .foregroundStyle(Nova.Color.textSubtle)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
        .background(Nova.Color.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: Nova.Radius.round, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Nova.Radius.round, style: .continuous).strokeBorder(Color(white: 0.82), lineWidth: 0.5))
        .novaElevation(.level3)
        .accessibilityElement(children: .contain)
    }

    private var badges: some View {
        HStack(spacing: 4) {
            if listing.isHotHome { badge("HOT HOME", Color(red: 166 / 255, green: 80 / 255, blue: 0)) }
            if listing.facts?.openHouse != nil { badge("OPEN HOUSE", Color(red: 91 / 255, green: 112 / 255, blue: 3 / 255)) }
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.nova(12, .demibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(color, in: Capsule())
    }
}
