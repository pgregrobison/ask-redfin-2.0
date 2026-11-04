import SwiftUI
import UIKit

struct ListingCardOverlay: View {
    let listing: Listing
    let isSaved: Bool
    let onDismiss: () -> Void
    let onToggleSave: () -> Void
    let onTap: () -> Void
    var zoomNamespace: Namespace.ID? = nil
    var extendsToBottomEdge: Bool = true
    @State private var currentPhotoIndex: Int = 0

    private let cardInset: CGFloat = Theme.Spacing.xs
    private let deviceEdgeInset: CGFloat = Theme.Spacing.xs

    private var cardCornerRadius: CGFloat {
        let screenRadius = UIScreen.main.value(forKey: ["Radius", "Corner", "display", "_"].reversed().joined()) as? CGFloat ?? 44
        return max(screenRadius - deviceEdgeInset, Theme.Radius.medium)
    }

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    photoCarousel
                    HomeCardInfoSection(
                        listing: listing,
                        size: .large,
                        isSaved: isSaved,
                        onToggleSave: onToggleSave
                    )
                }
                .background(Theme.Colors.secondaryBackground)
                .clipShape(.rect(cornerRadius: cardCornerRadius, style: .continuous))
                .shadow(color: Theme.Shadow.overlayColor, radius: Theme.Shadow.overlayRadius, y: Theme.Shadow.overlayY)
                .matchedTransitionSourceIfAvailable(id: listing.id, in: zoomNamespace)
                .padding(.horizontal, cardInset)
                .padding(.bottom, extendsToBottomEdge ? max(deviceEdgeInset - geo.safeAreaInsets.bottom, 0) : deviceEdgeInset)
            }
        }
        .ignoresSafeArea(edges: extendsToBottomEdge ? .bottom : [])
    }

    private var photoCarousel: some View {
        TabView(selection: $currentPhotoIndex) {
            ForEach(Array(listing.photos.prefix(5).enumerated()), id: \.offset) { index, url in
                Button(action: onTap) {
                    Theme.Colors.tertiaryBackground
                        .overlay {
                            AsyncImage(url: URL(string: url)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Theme.Colors.tertiaryBackground
                                } else {
                                    ProgressView()
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipped()
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: Theme.CardSize.PhotoHeight.medium)
        .clipShape(.rect(topLeadingRadius: cardCornerRadius, topTrailingRadius: cardCornerRadius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            GlassActionButton(icon: "xmark", action: onDismiss)
                .padding(Theme.Spacing.sm)
        }
        .overlay(alignment: .topLeading) {
            if let badge = listing.primaryBadge {
                badgeView(badge)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.leading, Theme.Spacing.lg)
            }
        }
    }

    private func badgeView(_ badge: HomeCardBadge) -> some View {
        Text(badge.text)
            .font(.nova(11, .demibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(badge.color, in: .rect(cornerRadius: Theme.Radius.small))
    }
}
