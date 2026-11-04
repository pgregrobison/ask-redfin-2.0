import SwiftUI

enum HomeCardSize {
    case large
    case medium
    case compact(width: CGFloat = 280)

    var photoHeight: CGFloat {
        switch self {
        case .large: Theme.CardSize.PhotoHeight.large
        case .medium: Theme.CardSize.PhotoHeight.medium
        case .compact: Theme.CardSize.PhotoHeight.compact
        }
    }

    /// Outer card corner radius (Figma node 1927:18714: 24px on the desktop
    /// grid card). The photo sits inset by `mattePadding` with a
    /// concentric inner radius, giving the same "framed" card the desktop
    /// prototype uses.
    var cornerRadius: CGFloat {
        switch self {
        case .large, .medium: 24
        case .compact: 16
        }
    }

    var mattePadding: CGFloat {
        switch self {
        case .large, .medium: 4
        case .compact: 3
        }
    }

    var innerPhotoRadius: CGFloat { cornerRadius - mattePadding }

    var fixedWidth: CGFloat? {
        switch self {
        case .large: nil
        case .medium: nil
        case .compact(let width): width
        }
    }

    var priceFont: Font {
        switch self {
        case .large, .medium: Theme.Typography.cardPrice
        case .compact: Theme.Typography.cardPriceCompact
        }
    }

    var statsFontSize: CGFloat {
        switch self {
        case .large, .medium: 14
        case .compact: 12
        }
    }

    var addressFontSize: CGFloat {
        switch self {
        case .large, .medium: 14
        case .compact: 12
        }
    }

    var infoPadding: EdgeInsets {
        switch self {
        case .large: Theme.CardSize.InfoPadding.large
        case .medium: Theme.CardSize.InfoPadding.medium
        case .compact: Theme.CardSize.InfoPadding.compact
        }
    }

    var showShareAction: Bool {
        switch self {
        case .large, .medium: true
        case .compact: false
        }
    }
}

struct HomeCard: View {
    let listing: Listing
    let size: HomeCardSize
    var isSaved: Bool = false
    var badge: HomeCardBadge? = nil
    var onToggleSave: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoSection
                .padding(size.mattePadding)
            HomeCardInfoSection(
                listing: listing,
                size: size,
                isSaved: isSaved,
                onToggleSave: onToggleSave
            )
        }
        .frame(width: size.fixedWidth)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: size.cornerRadius))
    }

    private var photoSection: some View {
        Theme.Colors.tertiaryBackground
            .frame(height: size.photoHeight)
            .overlay {
                AsyncImage(url: URL(string: listing.photos.first ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
                .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: size.innerPhotoRadius))
            .overlay(alignment: .topLeading) {
                if let badge {
                    badgeView(badge)
                        .padding(size.fixedWidth != nil ? 10 : Theme.Spacing.sm)
                }
            }
    }

    private func badgeView(_ badge: HomeCardBadge) -> some View {
        Text(badge.text)
            .font(.inter(11, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(badge.color, in: .rect(cornerRadius: Theme.Radius.small))
    }
}

enum HomeCardBadge {
    case hot
    case listedByRedfin
    case compassComingSoon
    case daysAgo(Int)

    var text: String {
        switch self {
        case .hot: "HOT HOME"
        case .listedByRedfin: "LISTED BY REDFIN"
        case .compassComingSoon: "COMPASS COMING SOON"
        case .daysAgo(let days): "\(days)d ago"
        }
    }

    var color: Color {
        switch self {
        case .hot: Theme.Colors.Badge.hot
        case .listedByRedfin: Theme.Colors.Badge.listedByRedfin
        case .compassComingSoon: Theme.Colors.Badge.compass
        case .daysAgo: Theme.Colors.Badge.daysAgo
        }
    }
}
