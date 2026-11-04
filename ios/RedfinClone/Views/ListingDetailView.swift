import SwiftUI
import MapKit

struct ListingDetailView: View {
    let listing: Listing
    let isSaved: Bool
    let useZoomTransition: Bool
    var hideAskRedfinFAB: Bool = false
    let onToggleSave: () -> Void
    let onAskRedfin: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFullDescription: Bool = false
    @State private var focusedPhotoIndex: Int? = nil
    @State private var sheetOffset: CGFloat = 0
    @State private var sheetSnap: SheetSnap = .collapsed
    @State private var dragStartOffset: CGFloat = 0
    @State private var scrolledToTop: Bool = true
    @State private var focusVisible: Bool = false
    @State private var minScrollOffsetDuringPhase: CGFloat = 0
    @State private var snapFeedback: Int = 0
    @State private var sheetDragActive: Bool = false
    @Environment(\.askRedfinContext) private var askRedfinContext

    private let collapsedPeekHeight: CGFloat = 220

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    private var sheetTopStop: CGFloat {
        safeAreaTop + 52 + 8
    }

    private var maxSheetTravel: CGFloat {
        UIScreen.main.bounds.height - sheetTopStop - collapsedPeekHeight
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                photoScroll
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                detailSheet(in: geo)

                if focusedPhotoIndex != nil {
                    focusOverlay
                }

                if !hideAskRedfinFAB {
                    stickyFooter
                }
            }
        }
        .onAppear { askRedfinContext.context = .detailHero }
        .onChange(of: focusedPhotoIndex) { _, idx in
            askRedfinContext.context = idx != nil ? .photoFocus : (sheetSnap == .expanded ? .detailFeatures : .detailHero)
        }
        .onChange(of: sheetSnap) { _, snap in
            guard focusedPhotoIndex == nil else { return }
            askRedfinContext.context = snap == .expanded ? .detailFeatures : .detailHero
        }
        .onDisappear { askRedfinContext.context = .default }
        .ignoresSafeArea()
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(useZoomTransition || focusedPhotoIndex != nil)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if focusedPhotoIndex != nil {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            focusVisible = false
                            focusedPhotoIndex = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                } else if useZoomTransition {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                if let index = focusedPhotoIndex {
                    Text("\(index + 1) of \(listing.photos.count)")
                        .font(.inter(15, .semibold))
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { onToggleSave() } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(isSaved ? .red : (focusedPhotoIndex != nil ? .white : .primary))
                }
                .sensoryFeedback(.selection, trigger: isSaved)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: listing.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(focusedPhotoIndex != nil ? .white : .primary)
                }
                .sensoryFeedback(.selection, trigger: false)
            }
        }
        .toolbarColorScheme(focusedPhotoIndex != nil ? .dark : nil, for: .navigationBar)
        .onDisappear {
            focusedPhotoIndex = nil
            focusVisible = false
        }
    }

    // MARK: - Photo Scroll

    private var photoScroll: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(Array(listing.photos.enumerated()), id: \.offset) { index, url in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            focusedPhotoIndex = index
                            focusVisible = true
                        }
                    } label: {
                        Theme.Colors.tertiaryBackground
                            .frame(height: 300)
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
                }

                Color.clear.frame(height: collapsedPeekHeight + 80)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Detail Sheet

    private func detailSheet(in geo: GeometryProxy) -> some View {
        let screenH = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom

        return VStack(spacing: 0) {
            sheetDragHandle
                .gesture(sheetDrag)
            sheetContent
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.background)
        .clipShape(.rect(topLeadingRadius: Theme.Radius.large, topTrailingRadius: Theme.Radius.large))
        .shadow(color: Theme.Shadow.mediumColor, radius: Theme.Shadow.mediumRadius, y: -5)
        .offset(y: screenH - collapsedPeekHeight - sheetOffset)
        .simultaneousGesture(collapsedSheetDrag)
        .sensoryFeedback(.impact(weight: .light), trigger: snapFeedback)
    }

    private var sheetDragHandle: some View {
        ZStack {
            Color.clear
                .frame(height: 28)
                .contentShape(Rectangle())
            Capsule()
                .fill(Color(.systemGray3))
                .frame(width: 36, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    // Drag gesture that only activates when the sheet is collapsed,
    // so any pull-up on the visible peek expands the sheet.
    private var collapsedSheetDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard sheetSnap == .collapsed else { return }
                let translation = -value.translation.height
                let newOffset = dragStartOffset + translation
                sheetOffset = max(0, min(maxSheetTravel, newOffset))
            }
            .onEnded { value in
                guard sheetSnap == .collapsed else { return }
                snapSheet(translationY: value.translation.height, predictedY: value.predictedEndTranslation.height)
            }
    }

    private var sheetDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = -value.translation.height
                let newOffset = dragStartOffset + translation
                sheetOffset = max(0, min(maxSheetTravel, newOffset))
            }
            .onEnded { value in
                snapSheet(translationY: value.translation.height, predictedY: value.predictedEndTranslation.height)
            }
    }

    private func snapSheet(translationY: CGFloat, predictedY: CGFloat) {
        let velocityY = predictedY - translationY
        let projectedOffset = sheetOffset - velocityY * 0.2
        // Asymmetric thresholds: easy to collapse from expanded (only ~20% pull),
        // but expanding from collapsed still requires a deliberate ~50% pull.
        let collapseThreshold = maxSheetTravel * 0.8  // expanded -> collapsed when below this
        let expandThreshold = maxSheetTravel * 0.5    // collapsed -> expanded when above this
        let fastFlickDown = velocityY > 500
        let fastFlickUp = velocityY < -500

        let shouldExpand: Bool = {
            if fastFlickUp { return true }
            if fastFlickDown { return false }
            if sheetSnap == .expanded {
                return projectedOffset >= collapseThreshold
            } else {
                return projectedOffset > expandThreshold
            }
        }()

        let previousSnap = sheetSnap
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            if shouldExpand {
                sheetOffset = maxSheetTravel
                sheetSnap = .expanded
            } else {
                sheetOffset = 0
                sheetSnap = .collapsed
            }
        }
        dragStartOffset = sheetSnap == .expanded ? maxSheetTravel : 0
        if sheetSnap != previousSnap { snapFeedback &+= 1 }
    }

    // Real-time collapse drag: only activates when expanded and the inner
    // ScrollView is at scroll top, and only on downward drags. Mirrors the
    // collapsed→expanded pull behavior 1:1.
    private var expandedContentDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard sheetSnap == .expanded, scrolledToTop else { return }
                if !sheetDragActive {
                    // Take over on the very first downward pixel so the
                    // ScrollView never gets a chance to rubber-band.
                    guard value.translation.height > 0 else { return }
                    sheetDragActive = true
                    dragStartOffset = sheetOffset
                }
                let newOffset = dragStartOffset - value.translation.height
                sheetOffset = max(0, min(maxSheetTravel, newOffset))
            }
            .onEnded { value in
                guard sheetDragActive else { return }
                sheetDragActive = false
                snapSheet(translationY: value.translation.height, predictedY: value.predictedEndTranslation.height)
            }
    }

    private var sheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                    .padding(.horizontal, Theme.Spacing.lg)

                if sheetSnap == .expanded {
                    expandedContent
                }

                Color.clear.frame(height: 100)
            }
        }
        .scrollDisabled(sheetSnap == .collapsed || sheetDragActive)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, y in
            scrolledToTop = y <= 1
        }
        .simultaneousGesture(expandedContentDrag)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(listing.formattedFullPrice)
                    .font(Theme.Typography.heroPrice)

                HStack(spacing: Theme.Spacing.xs) {
                    Text("\(listing.beds) bd")
                    Text("\(listing.bathsFormatted) ba")
                    Text("\(listing.sqft.formatted()) sq ft")
                }
                .font(Theme.Typography.secondary)
                .foregroundStyle(.secondary)

                Text(listing.fullAddress)
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            miniMapThumbnail
        }
    }

    private var miniMapThumbnail: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: listing.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Annotation("", coordinate: listing.coordinate) {
                Circle()
                    .fill(Theme.redfinGreenColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .frame(width: 70, height: 70)
        .clipShape(.rect(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.vertical, Theme.Spacing.md)

            aboutSection
                .padding(.horizontal, Theme.Spacing.lg)

            metaStatsRow
                .padding(.top, Theme.Spacing.lg)
                .padding(.horizontal, Theme.Spacing.lg)

            Divider().padding(.vertical, Theme.Spacing.md)

            keyFactsSection
                .padding(.horizontal, Theme.Spacing.lg)

            if listing.isHotHome {
                hotHomeBadge
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
            }

            if !listing.tags.isEmpty {
                highlightsSection
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
            }

            Divider().padding(.vertical, Theme.Spacing.md)

            moreSections
                .padding(.horizontal, Theme.Spacing.lg)

            if hideAskRedfinFAB {
                inlineRequestShowingButton
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
            }
        }
        .transition(.opacity)
    }

    private var inlineRequestShowingButton: some View {
        Button(action: {}) { Text("Request showing") }
            .buttonStyle(.primary)
    }

    // MARK: - Footer

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Spacer()
            detailFooter
        }
    }

    private var detailFooter: some View {
        HStack(spacing: Theme.Spacing.sm) {
            requestShowingButton

            if !hideAskRedfinFAB {
                askRedfinButton
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, max(safeAreaBottom, Theme.Spacing.sm))
    }

    private var askRedfinButton: some View {
        GlassActionButton(icon: "sparkle", action: onAskRedfin, size: 52)
    }

    @ViewBuilder
    private var requestShowingButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: {}) {
                Text("Request showing")
                    .font(Theme.Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
            }
            .glassEffect(.regular.tint(.red).interactive(), in: .capsule)
        } else {
            Button(action: {}) {
                Text("Request showing")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.brandRed, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Focus Photo Overlay

    private var focusOverlay: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let index = focusedPhotoIndex, focusVisible {
                TabView(selection: Binding(
                    get: { index },
                    set: { focusedPhotoIndex = $0 }
                )) {
                    ForEach(Array(listing.photos.enumerated()), id: \.offset) { i, url in
                        AsyncImage(url: URL(string: url)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else if phase.error != nil {
                                Color.clear
                            } else {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .transition(.opacity)
            }
        }
        .allowsHitTesting(focusVisible)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs + 2) {
            Text("About this home")
                .font(Theme.Typography.cardTitle)

            Text(listing.description)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .lineLimit(showFullDescription ? nil : 4)

            if listing.description.count > 120 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFullDescription.toggle()
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Text(showFullDescription ? "Show less" : "Continue reading")
                        Image(systemName: showFullDescription ? "chevron.up" : "chevron.down")
                            .font(Theme.Typography.captionBold)
                    }
                }
                .buttonStyle(.textLink)
            }
        }
    }

    // MARK: - Meta Stats

    private var metaStatsRow: some View {
        HStack(spacing: 0) {
            metaStat(value: "\(listing.daysOnMarket) days", label: "on Redfin")
            Divider().frame(height: 40)
            metaStat(value: "\(listing.viewsCount)", label: "views")
            Divider().frame(height: 40)
            metaStat(value: "\(listing.favoritesCount)", label: "favorites")
        }
    }

    private func metaStat(value: String, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.headline)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Key Facts

    private var keyFactsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Key facts")
                .font(Theme.Typography.cardTitle)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                keyFactRow(icon: "house", value: listing.propertyType, label: "Property type")
                keyFactRow(icon: "calendar", value: "\(listing.yearBuilt)", label: "Year built")
                keyFactRow(icon: "arrow.up.left.and.arrow.down.right", value: listing.lotSize, label: "Lot size")
                keyFactRow(icon: "dollarsign.circle", value: "$\(listing.pricePerSqFt)", label: "Per sq. ft.")
                keyFactRow(icon: "shield", value: listing.hoaDues, label: "HOA dues")
                keyFactRow(icon: "percent", value: listing.buyerAgentFee, label: "Buyer's agent fee")
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: Theme.Radius.medium))
    }

    private func keyFactRow(icon: String, value: String, label: String) -> some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(Theme.Typography.secondaryBold)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hot Home

    private var hotHomeBadge: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: "flame")
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hot Home")
                    .font(Theme.Typography.headline)
                Text("This home is likely to sell quickly.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Highlights

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Highlights")
                .font(Theme.Typography.cardTitle)

            TagGrid(tags: listing.tags)
        }
    }

    // MARK: - More Sections

    private var moreSections: some View {
        VStack(spacing: 0) {
            disclosureRow(icon: "building.2", title: "Neighborhood insights")
            Divider().padding(.leading, Theme.DividerInset.disclosureRow)
            disclosureRow(icon: "chart.line.uptrend.xyaxis", title: "Price history")
            Divider().padding(.leading, Theme.DividerInset.disclosureRow)
            disclosureRow(icon: "graduationcap", title: "Schools nearby")
        }
        .padding(Theme.Spacing.xxs)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: Theme.Radius.medium))
    }

    private func disclosureRow(icon: String, title: String) -> some View {
        Button(action: {}) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: Theme.Spacing.sm + 2, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private enum SheetSnap {
    case collapsed
    case expanded
}

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
