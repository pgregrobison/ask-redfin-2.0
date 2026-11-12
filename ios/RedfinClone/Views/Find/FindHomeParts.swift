import SwiftUI
import UIKit

// Pieces shared by the iOS Vision home cards (carousel and list).

/// A listing photo. Bundled `file://` photos load synchronously from a cache
/// so paging never flashes a spinner; remote ones use `AsyncImage`.
struct ListingPhoto: View {
    let url: String?

    var body: some View {
        Nova.Color.bgTertiary
            .overlay {
                if let image = LocalPhotoCache.image(for: url) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let url, let remote = URL(string: url), remote.scheme?.hasPrefix("http") == true {
                    AsyncImage(url: remote) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

@MainActor
private enum LocalPhotoCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for url: String?) -> UIImage? {
        guard let url, url.hasPrefix("file://"), let path = URL(string: url)?.path else { return nil }
        if let hit = cache.object(forKey: path as NSString) { return hit }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

/// "**4** bd  **2.5** ba  **2,083** sq ft"
struct HomeFactsLine: View {
    let listing: Listing
    var numberWeight: Font.NovaWeight = .demibold

    var body: some View {
        HStack(spacing: 8) {
            fact(String(listing.beds), "bd")
            fact(listing.bathsFormatted, "ba")
            fact(listing.sqft > 0 ? listing.sqft.formatted() : "—", "sq ft")
        }
        .font(Nova.Typography.body14)
        .foregroundStyle(Nova.Color.text)
        .lineLimit(1)
    }

    private func fact(_ number: String, _ unit: String) -> Text {
        Text("\(Text(number).font(.nova(14, numberWeight))) \(unit)")
    }
}

/// "✓ 4/5": tinted from warm gray toward green by how many criteria match.
struct MatchBadge: View {
    let ranking: RankedHome

    var body: some View {
        if let label = ranking.matchLabel {
            HStack(spacing: 2) {
                NovaIcon("check", size: 16)
                Text(label).font(Nova.Typography.label14)
            }
            .foregroundStyle(Self.mix(Self.textFrom, Self.textTo, ranking.matchFraction))
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Self.mix(Self.bgFrom, Self.bgTo, ranking.matchFraction), in: RoundedRectangle(cornerRadius: Nova.Radius.tag))
            .accessibilityLabel("Matches \(ranking.matched.count) of \(ranking.total) features")
        }
    }

    // #F5F3F0 → green-50, gray-800 → green-800
    private static let bgFrom = (245.0, 243.0, 240.0), bgTo = (239.0, 247.0, 243.0)
    private static let textFrom = (17.0, 17.0, 17.0), textTo = (9.0, 74.0, 43.0)

    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> Color {
        Color(red: (a.0 + (b.0 - a.0) * t) / 255, green: (a.1 + (b.1 - a.1) * t) / 255, blue: (a.2 + (b.2 - a.2) * t) / 255)
    }
}

/// 44pt heart: outline when unsaved, filled brand red when saved.
struct SaveHeartButton: View {
    let isSaved: Bool
    var onPhoto = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NovaIcon(isSaved ? "favorite_filled" : "favorite", size: 24)
                .foregroundStyle(isSaved ? Nova.Color.brandFixed : (onPhoto ? .white : Nova.Color.text))
                .shadow(color: onPhoto ? .black.opacity(0.3) : .clear, radius: 3, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
        .accessibilityLabel(isSaved ? "Remove from saved homes" : "Save home")
    }
}

/// Warm page background behind the list (#F5F3F0 in light mode).
extension Nova.Color {
    static let canvas = SwiftUI.Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 27 / 255, green: 27 / 255, blue: 27 / 255, alpha: 1)
            : UIColor(red: 245 / 255, green: 243 / 255, blue: 240 / 255, alpha: 1)
    })
}
