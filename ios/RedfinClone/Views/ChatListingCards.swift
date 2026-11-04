import SwiftUI

struct ChatListingCards: View {
    let listingIds: [String]
    let allListings: [Listing]
    let savedListingIDs: Set<String>
    let onToggleSave: (Listing) -> Void
    let filters: SearchFilters?
    let onShowOnMap: ([Listing], SearchFilters?) -> Void
    let onListingTap: (Listing) -> Void
    @Binding var scrolledListingID: String?
    var zoomNamespace: Namespace.ID?
    @State private var hasAppeared: Bool = false

    private var matchedListings: [Listing] {
        listingIds.compactMap { id in
            allListings.first { $0.id == id }
        }
    }

    var body: some View {
        // Figma (🏠 Homes block): 8pt gap between the card row and the
        // Show on map button, and 8pt between carousel cards.
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if matchedListings.count == 1, let listing = matchedListings.first {
                // A single match renders as one prominent full-width card
                // instead of a narrow carousel card with empty space beside it.
                Button { onListingTap(listing) } label: {
                    card(for: listing, fixedWidth: nil)
                }
                .buttonStyle(.plain)
                .padding(.leading, Theme.Spacing.md)
                .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
                .matchedTransitionSourceIfAvailable(id: listing.id, in: zoomNamespace)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(matchedListings) { listing in
                            Button { onListingTap(listing) } label: {
                                card(for: listing, fixedWidth: DemoFixtures.isEnabled ? 301 : 300)
                            }
                            .buttonStyle(.plain)
                            .id(listing.id)
                            .matchedTransitionSourceIfAvailable(id: listing.id, in: zoomNamespace)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrolledListingID)
                .contentMargins(.leading, Theme.Spacing.md)
                .contentMargins(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
                .scrollIndicators(.hidden)
            }

            if !matchedListings.isEmpty {
                Button {
                    let nyListings = matchedListings.filter { $0.state == "NY" }
                    onShowOnMap(nyListings.isEmpty ? matchedListings : nyListings, filters)
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "map")
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        Text("Show on map")
                            .font(.inter(14, .bold))
                    }
                    .foregroundStyle(Theme.Colors.invertedPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
                    .background(Color.primary, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, Theme.Spacing.md)
                .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : Theme.Spacing.md)
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
    }

    @ViewBuilder
    private func card(for listing: Listing, fixedWidth: CGFloat?) -> some View {
        if DemoFixtures.isEnabled {
            ChatDemoHomeCard(
                listing: listing,
                fixedWidth: fixedWidth,
                isSaved: savedListingIDs.contains(listing.id),
                onToggleSave: { onToggleSave(listing) }
            )
        } else {
            HomeCard(
                listing: listing,
                size: fixedWidth == nil ? .medium : .compact(width: fixedWidth!),
                isSaved: savedListingIDs.contains(listing.id),
                badge: listing.primaryBadge,
                onToggleSave: { onToggleSave(listing) }
            )
        }
    }
}

/// Chat-specific home card matching the desktop-companion "🍎 Home card
/// (brokerage)" pattern (Figma node 718:3556) — deliberately distinct from
/// `HomeCard` (used on the Find tab and everywhere else): thinner hairline
/// border, no photo matte, plain space-separated stats with no dot
/// separators, and a full-opacity address. Scoped to Launch Demo only so the
/// rest of the app keeps the existing `HomeCard` styling.
private struct ChatDemoHomeCard: View {
    let listing: Listing
    var fixedWidth: CGFloat?
    var isSaved: Bool
    var onToggleSave: () -> Void

    private static let photoAspectRatio: CGFloat = 301.0 / 238.667

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed-aspect spacer + overlay (mirrors Figma's
            // "Fixed-aspect-ratio-spacer" pattern): the placeholder sizes the
            // slot from the proposed width, and the photo fills inside it —
            // `.fill` directly on the AsyncImage would instead inflate the
            // card's own layout beyond the screen.
            Theme.Colors.tertiaryBackground
                .aspectRatio(Self.photoAspectRatio, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: listing.photos.first ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(listing.formattedFullPrice)
                        .font(.inter(18, .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.md)
                    Button(action: onToggleSave) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(isSaved ? .red : .primary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }

                HStack(spacing: 12) {
                    statPair(value: "\(listing.beds)", unit: "bd")
                    statPair(value: listing.bathsFormatted, unit: "ba")
                    statPair(value: listing.sqft.formatted(), unit: "sq ft")
                }
                .font(.inter(14))
                .foregroundStyle(.primary)

                Text(listing.fullAddress)
                    .font(.inter(12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: fixedWidth, alignment: .leading)
        .frame(maxWidth: fixedWidth == nil ? .infinity : nil, alignment: .leading)
        .background(Theme.Colors.background)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.separator, lineWidth: 0.5)
        )
    }

    private func statPair(value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
            Text(unit)
        }
    }
}
