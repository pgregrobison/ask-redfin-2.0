import SwiftUI

/// The iOS Vision list: "{N} homes in {area} under $1.3M" with Save search,
/// then ranked home cards 24 at a time.
struct FindListView: View {
    @Bindable var viewModel: ListingsViewModel
    var zoomNamespace: Namespace.ID
    let onListingTap: (Listing) -> Void

    @State private var containerMinY: CGFloat = 0
    private let pageSize = 24

    private var results: [RankedHome] { viewModel.rankedResults }
    private var shown: ArraySlice<RankedHome> { results.prefix(viewModel.listPageCount * pageSize) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    ForEach(shown) { ranked in
                        ListingResultCard(
                            ranked: ranked,
                            isSaved: viewModel.isSaved(ranked.listing),
                            isHighlighted: viewModel.search.highlighted.contains(ranked.id),
                            onToggleSave: { viewModel.toggleSaved(ranked.listing) }
                        )
                        .onTapGesture { onListingTap(ranked.listing) }
                        .matchedTransitionSource(id: ranked.id, in: zoomNamespace)
                        .id(ranked.id)
                    }
                    if results.count > shown.count {
                        Button("Show \(min(pageSize, results.count - shown.count)) more of \(results.count) homes") {
                            viewModel.listPageCount += 1
                        }
                        .buttonStyle(.nova(.secondary, size: .small, fullWidth: true))
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, max(viewModel.topChromeMaxY - containerMinY, 0) + 22)
                .padding(.bottom, Theme.Spacing.tabBarClearance)
            }
            .onChange(of: viewModel.search.highlighted) { _, ids in
                guard let first = results.first(where: { ids.contains($0.id) }) else { return }
                if let index = results.firstIndex(of: first), index >= shown.count {
                    viewModel.listPageCount = index / pageSize + 1
                }
                withAnimation(.easeOut(duration: 0.8)) { proxy.scrollTo(first.id, anchor: UnitPoint(x: 0.5, y: 0.15)) }
            }
        }
        .background(Nova.Color.canvas)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { containerMinY = $0 }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(results.count == 1 ? "1 home" : "\(results.count) homes") in \(viewModel.search.locationPhrase)\(viewModel.search.pricePhrase)")
                .font(.nova(20, .demibold))
                .tracking(-0.4)
                .foregroundStyle(Nova.Color.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(viewModel.search.savedSearch ? "Saved" : "Save search") {
                viewModel.changeSearch { $0.savedSearch.toggle() }
            }
            .buttonStyle(.nova(viewModel.search.savedSearch ? .secondary : .primary, size: .small))
            .sensoryFeedback(.success, trigger: viewModel.search.savedSearch) { _, saved in saved }
        }
    }
}

/// A list result: 3:2 photo with Hot home tag and save, then price with the
/// match badge, facts and address.
struct ListingResultCard: View {
    let ranked: RankedHome
    let isSaved: Bool
    var isHighlighted = false
    let onToggleSave: () -> Void

    private var listing: Listing { ranked.listing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListingPhoto(url: listing.photos.first)
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay {
                    LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.4))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if listing.isHotHome {
                        NovaTag(title: "Hot home", variant: .rocket, size: .small).padding(12)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    SaveHeartButton(isSaved: isSaved, onPhoto: true, action: onToggleSave).padding(4)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(listing.formattedFullPrice)
                        .font(.nova(20, .demibold))
                        .foregroundStyle(Nova.Color.text)
                    Spacer()
                    MatchBadge(ranking: ranked)
                }
                HomeFactsLine(listing: listing, numberWeight: .medium)
                Text(listing.fullAddress)
                    .font(Nova.Typography.caption12)
                    .foregroundStyle(Nova.Color.textSubtle)
                    .lineLimit(1)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        }
        .novaCard(.secondary, padding: nil)
        .contentShape(RoundedRectangle(cornerRadius: Nova.Radius.card))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Nova.Radius.card)
                    .strokeBorder(Nova.Color.brandFixed, lineWidth: 2)
                    .shadow(color: Nova.Color.brandFixed.opacity(0.32), radius: 18, y: 12)
            }
        }
        .animation(Nova.Motion.easeOut(), value: isHighlighted)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
