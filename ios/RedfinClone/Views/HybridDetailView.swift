import SwiftUI
import MapKit

struct HybridDetailView: View {
    let listing: Listing
    let isSaved: Bool
    let useZoomTransition: Bool
    var hideAskRedfinFAB: Bool = false
    let onToggleSave: () -> Void
    let onAskRedfin: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showFullDescription: Bool = false
    @State private var downPaymentPercent: Double = 20
    @State private var focusedPhotoIndex: Int? = nil
    @State private var focusVisible: Bool = false
    @State private var sheetOffset: CGFloat = 0
    @State private var sheetSnap: HybridSheetSnap = .collapsed
    @State private var dragStartOffset: CGFloat = 0
    @State private var scrolledToTop: Bool = true
    @State private var minScrollOffsetDuringPhase: CGFloat = 0
    @State private var snapFeedback: Int = 0
    @State private var sheetScrollY: CGFloat = 0
    @State private var sheetDragActive: Bool = false
    @Environment(\.askRedfinContext) private var askRedfinContext

    private let redfinRed = Theme.Colors.brandRed
    private let tourIllustrationURL = "https://r2-pub.rork.com/generated-images/d2e764d4-6e36-4e51-ab3d-a5c3d148f6b5.png"
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

    private var monthlyPayment: Int {
        let principal = Double(listing.price) * (1.0 - downPaymentPercent / 100.0)
        let annualRate = 0.0667
        let monthlyRate = annualRate / 12.0
        let months = 360.0
        guard monthlyRate > 0 else { return 0 }
        let payment = principal * (monthlyRate * pow(1 + monthlyRate, months)) / (pow(1 + monthlyRate, months) - 1)
        return Int(payment)
    }

    private var principalAndInterest: Int { monthlyPayment }
    private var propertyTaxes: Int { Int(Double(listing.price) * 0.012 / 12.0) }
    private var homeInsurance: Int { Int(Double(listing.price) * 0.005 / 12.0) }

    private var hoaDuesAmount: Int {
        let cleaned = listing.hoaDues
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "/mo", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Int(cleaned) ?? 0
    }

    private var totalMonthly: Int {
        principalAndInterest + propertyTaxes + homeInsurance + hoaDuesAmount
    }

    private let featureIcons: [String] = ["shower", "door.garage.closed", "oven", "bed.double", "hanger", "umbrella"]

    private var featureHighlights: [(icon: String, label: String)] {
        var highlights: [(icon: String, label: String)] = []
        for (index, tag) in listing.tags.prefix(6).enumerated() {
            let icon = index < featureIcons.count ? featureIcons[index] : featureIcons[index % featureIcons.count]
            highlights.append((icon: icon, label: tag))
        }
        if highlights.count < 6 {
            let generated: [(icon: String, label: String)] = [
                ("bed.double", "\(listing.beds) bedrooms"),
                ("shower", "\(listing.bathsFormatted) bathrooms"),
                ("oven", "\(listing.sqft.formatted()) sq ft"),
                ("door.garage.closed", "Built in \(listing.yearBuilt)"),
                ("hanger", listing.lotSize + " lot"),
                ("umbrella", listing.propertyType)
            ]
            for item in generated {
                guard highlights.count < 6 else { break }
                let isDuplicate = highlights.contains { $0.label.lowercased() == item.label.lowercased() }
                if !isDuplicate { highlights.append(item) }
            }
        }
        return Array(highlights.prefix(6))
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
            }
        }
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
            }
        }
        .toolbarColorScheme(focusedPhotoIndex != nil ? .dark : nil, for: .navigationBar)
        .onAppear { updateAskContext() }
        .onChange(of: focusedPhotoIndex) { _, _ in updateAskContext() }
        .onChange(of: sheetSnap) { _, _ in updateAskContext() }
        .onChange(of: sheetScrollY) { _, _ in updateAskContext() }
        .onDisappear {
            focusedPhotoIndex = nil
            focusVisible = false
            askRedfinContext.context = .default
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
                            .contentShape(.rect)
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
        let collapseThreshold = maxSheetTravel * 0.8
        let expandThreshold = maxSheetTravel * 0.5
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
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard sheetSnap == .expanded, scrolledToTop else { return }
                if !sheetDragActive {
                    // Activate on the very first downward movement so the
                    // ScrollView never has a chance to rubber-band.
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

    private func updateAskContext() {
        if focusedPhotoIndex != nil {
            askRedfinContext.context = .photoFocus
            return
        }
        guard sheetSnap == .expanded else {
            askRedfinContext.context = .detailHero
            return
        }
        let scrolled = -sheetScrollY
        if scrolled < 280 {
            askRedfinContext.context = .detailPrice
        } else if scrolled < 780 {
            askRedfinContext.context = .detailFeatures
        } else {
            askRedfinContext.context = .detailLifestyle
        }
    }

    private var sheetContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                priceAndAddressSection
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.xs)

                if sheetSnap == .expanded {
                    expandedSections
                }

                Color.clear.frame(height: 120)
            }
        }
        .scrollDisabled(sheetSnap == .collapsed || sheetDragActive)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, y in
            scrolledToTop = y <= 1
            sheetScrollY = -y
        }
        .simultaneousGesture(expandedContentDrag)
    }

    @ViewBuilder
    private var expandedSections: some View {
        VStack(spacing: Theme.Container.spacing) {
            rateSummarySection
            requestShowingSection

            sectionContainer { propertyDetailsContent }
            sectionContainer { featureAndDescriptionContent }
            sectionContainer(accent: true) { ratePaymentContent }
            sectionContainer { takeTourContent }
            sectionContainer { askRedfinContent }
            sectionContainer { lifestyleContent }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.lg)
        .transition(.opacity)
    }

    // MARK: - Focus Photo Overlay

    private var focusOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let index = focusedPhotoIndex, focusVisible {
                TabView(selection: Binding(
                    get: { index },
                    set: { focusedPhotoIndex = $0 }
                )) {
                    ForEach(Array(listing.photos.enumerated()), id: \.offset) { i, url in
                        AsyncImage(url: URL(string: url)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else if phase.error != nil {
                                Color.clear
                            } else {
                                ProgressView().tint(.white)
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

    // MARK: - James' Sections

    private func sectionContainer<Content: View>(accent: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Theme.Container.padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Container.radius, style: .continuous)
                    .stroke(
                        accent ? Theme.Colors.separator.opacity(0.8) : Theme.Container.borderColor,
                        lineWidth: Theme.Container.borderWidth
                    )
            )
    }

    private var priceAndAddressSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(listing.formattedFullPrice)
                .font(Theme.Typography.heroNumber)

            HStack(spacing: Theme.Spacing.xxs) {
                Text("\(listing.beds) beds")
                Text("·")
                Text("\(listing.bathsFormatted) baths")
                Text("·")
                Text("\(listing.sqft.formatted()) sq ft")
            }
            .font(.inter(18, .semibold))
            .foregroundStyle(.primary)

            Text(listing.fullAddress)
                .font(Theme.Typography.secondary)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Theme.Spacing.xs)
    }

    private var rateSummarySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("$\(totalMonthly.formatted())/mo")
                    .font(.inter(20, .bold))
                    .foregroundStyle(.primary)
                HStack(spacing: Theme.Spacing.xxs) {
                    Text("Rates dropped")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.primary)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                }
            }
            Spacer()
            Button(action: {}) {
                Text("Estimate my rate")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .background(Theme.Colors.brandGreen, in: Capsule())
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.inset, in: .rect(cornerRadius: Theme.Container.radius))
    }

    private var requestShowingSection: some View {
        Button(action: {}) { Text("Request showing") }
            .buttonStyle(.primary)
    }

    private var propertyDetailsContent: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xl) {
            propertyDetailRow(icon: "house", value: listing.propertyType, label: "Property type")
            propertyDetailRow(icon: "calendar", value: "\(listing.yearBuilt)", label: "Year built")
            propertyDetailRow(icon: "arrow.up.left.and.arrow.down.right", value: listing.lotSize, label: "Lot size")
            propertyDetailRow(icon: "dollarsign.circle", value: "$\(listing.pricePerSqFt)", label: "Per sq. ft.")
            propertyDetailRow(icon: "chart.line.uptrend.xyaxis", value: listing.formattedFullPrice, label: "Redfin Estimate")
            propertyDetailRow(icon: "banknote", value: listing.hoaDues == "N/A" ? "$0" : listing.hoaDues, label: "HOA dues")
        }
    }

    private func propertyDetailRow(icon: String, value: String, label: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs + 2) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(Theme.Typography.secondaryBold)
                Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureAndDescriptionContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xl) {
                ForEach(Array(featureHighlights.enumerated()), id: \.offset) { _, highlight in
                    iconTagCell(icon: highlight.icon, label: highlight.label)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(listing.description)
                    .font(Theme.Typography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(showFullDescription ? nil : 3)

                if listing.description.count > 100 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showFullDescription.toggle() }
                    } label: {
                        HStack(spacing: Theme.Spacing.xxs) {
                            Text(showFullDescription ? "Show less" : "Continue reading")
                            Image(systemName: showFullDescription ? "chevron.up" : "chevron.down")
                                .font(Theme.Typography.captionBold)
                        }
                    }
                    .buttonStyle(.textLink)
                }

                Button(action: {}) { Text("Full property details") }
                    .buttonStyle(.secondary)
                    .padding(.top, Theme.Spacing.xxs)
            }
        }
    }

    private func iconTagCell(icon: String, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconTag.iconSize, weight: .medium))
                .foregroundStyle(Theme.IconTag.iconColor)
            TagView(text: label)
        }
        .frame(maxWidth: .infinity)
    }

    private var ratePaymentContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("$\(totalMonthly.formatted()) /mo")
                .font(Theme.Typography.largeNumber)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, Theme.Spacing.xs)

            paymentBreakdownList
            paymentBar

            HStack(spacing: Theme.Spacing.sm) {
                FilledInputView(label: "Home price", value: listing.formattedFullPrice)
                FilledInputView(label: "Down payment", value: "\(Int(downPaymentPercent))% (\(shorthandDollar(Int(Double(listing.price) * downPaymentPercent / 100.0))))")
            }

            FilledInputView(label: "Loan details", value: "30-yr fixed, 6.67%")

            Button(action: {}) { Text("Estimate my payment & rate") }
                .buttonStyle(.primary)

            Divider()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark")
                        .font(Theme.Typography.captionBold)
                        .foregroundStyle(Theme.Colors.brandGreen)
                    Text("Takes about 3 minutes")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark")
                        .font(Theme.Typography.captionBold)
                        .foregroundStyle(Theme.Colors.brandGreen)
                    Text("Won't affect your credit score")
                        .font(Theme.Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var paymentBreakdownList: some View {
        VStack(spacing: 0) {
            paymentLineItem(color: Theme.Colors.Chart.blue, label: "Principal and interest", amount: principalAndInterest, percent: totalMonthly > 0 ? Int(Double(principalAndInterest) / Double(totalMonthly) * 100) : 0)
            Divider().padding(.vertical, Theme.Spacing.md)
            paymentLineItem(color: Theme.Colors.Chart.green, label: "Property taxes", amount: propertyTaxes, percent: totalMonthly > 0 ? Int(Double(propertyTaxes) / Double(totalMonthly) * 100) : 0)
            Divider().padding(.vertical, Theme.Spacing.md)
            paymentLineItem(color: Theme.Colors.Chart.amber, label: "Homeowners insurance", amount: homeInsurance, percent: totalMonthly > 0 ? Int(Double(homeInsurance) / Double(totalMonthly) * 100) : 0)
            if hoaDuesAmount > 0 {
                Divider().padding(.vertical, Theme.Spacing.md)
                paymentLineItem(color: Theme.Colors.Chart.purple, label: "HOA dues", amount: hoaDuesAmount, percent: totalMonthly > 0 ? Int(Double(hoaDuesAmount) / Double(totalMonthly) * 100) : 0)
            }
        }
    }

    private func paymentLineItem(color: Color, label: String, amount: Int, percent: Int) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(Theme.Typography.secondary)
            Spacer()
            Text("$\(amount.formatted()) (\(percent)%)")
                .font(Theme.Typography.secondary)
                .foregroundStyle(.secondary)
        }
    }

    private var paymentBar: some View {
        GeometryReader { geo in
            let total = max(CGFloat(totalMonthly), 1)
            let piWidth = geo.size.width * CGFloat(principalAndInterest) / total
            let taxWidth = geo.size.width * CGFloat(propertyTaxes) / total
            let insWidth = geo.size.width * CGFloat(homeInsurance) / total
            let hoaWidth = geo.size.width * CGFloat(hoaDuesAmount) / total

            HStack(spacing: Theme.Spacing.xxs) {
                Rectangle().fill(Theme.Colors.Chart.blue).frame(width: max(piWidth, 2))
                Rectangle().fill(Theme.Colors.Chart.green).frame(width: max(taxWidth, 2))
                Rectangle().fill(Theme.Colors.Chart.amber).frame(width: max(insWidth, 2))
                if hoaDuesAmount > 0 {
                    Rectangle().fill(Theme.Colors.Chart.purple).frame(width: max(hoaWidth, 2))
                }
            }
        }
        .frame(height: 8)
        .clipShape(.rect(cornerRadius: 4))
    }

    private func shorthandDollar(_ amount: Int) -> String {
        if amount >= 1_000_000 {
            let m = Double(amount) / 1_000_000.0
            return m.truncatingRemainder(dividingBy: 1) == 0 ? "$\(Int(m))M" : String(format: "$%.1fM", m)
        } else if amount >= 1_000 {
            let k = Double(amount) / 1_000.0
            return k.truncatingRemainder(dividingBy: 1) == 0 ? "$\(Int(k))K" : String(format: "$%.0fK", k)
        }
        return "$\(amount)"
    }

    private var takeTourContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Take a tour")
                .font(Theme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            AsyncImage(url: URL(string: tourIllustrationURL)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit).frame(height: 180)
                } else {
                    Image(systemName: "house.fill")
                        .font(Theme.Typography.decorativeXL)
                        .foregroundStyle(redfinRed.opacity(0.15))
                }
            }
            .padding(.bottom, Theme.Spacing.xxs)

            Button(action: {}) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "person.2")
                    Text("Tour in person")
                }
            }
            .buttonStyle(.primary)

            Button(action: {}) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "video")
                    Text("Tour via video chat")
                }
            }
            .buttonStyle(.secondary)

            Text("It's free, cancel anytime.")
                .font(Theme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var askRedfinContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Ask Redfin")
                .font(Theme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            Image(systemName: "sparkle")
                .font(Theme.Typography.decorativeLG)
                .foregroundStyle(redfinRed)

            Text("I'm here to help answer your questions about this property or your services. I can also connect you with a licensed advisor.")
                .font(Theme.Typography.secondary)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAskRedfin) {
                HStack(spacing: Theme.Spacing.xxs + 2) {
                    Image(systemName: "sparkle")
                    Text("Ask about \(listing.address)")
                }
            }
            .buttonStyle(.secondary)
        }
    }

    private var lifestyleContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Lifestyle")
                .font(Theme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xl) {
                iconTagCell(icon: "figure.walk", label: "Walker's paradise")
                iconTagCell(icon: "bicycle", label: "Some bike-ability")
                iconTagCell(icon: "speaker.slash", label: "Silent zone")
                iconTagCell(icon: "leaf", label: "Always calm")
            }

            Button(action: {}) {
                Text("How is this calculated?")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .underline()
            }

            Text("Provided by Walk Score and Local Logic")
                .font(Theme.Typography.micro)
                .foregroundStyle(.tertiary)
        }
    }
}

private enum HybridSheetSnap {
    case collapsed
    case expanded
}
