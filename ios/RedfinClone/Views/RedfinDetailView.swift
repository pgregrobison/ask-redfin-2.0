import SwiftUI
import MapKit

struct RedfinDetailView: View {
    let listing: Listing
    let isSaved: Bool
    let useZoomTransition: Bool
    var hideAskRedfinFAB: Bool = false
    let onToggleSave: () -> Void
    let onAskRedfin: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPhotoIndex: Int = 0
    @State private var showFullDescription: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var homePrice: String = ""
    @State private var downPaymentPercent: Double = 20
    @State private var selectedMediaTab: Int = 0
    @Environment(\.askRedfinContext) private var askRedfinContext

    private let redfinRed = Theme.Colors.brandRed
    private let tourIllustrationURL = "https://r2-pub.rork.com/generated-images/d2e764d4-6e36-4e51-ab3d-a5c3d148f6b5.png"

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

    private var propertyTaxes: Int {
        Int(Double(listing.price) * 0.012 / 12.0)
    }

    private var homeInsurance: Int {
        Int(Double(listing.price) * 0.005 / 12.0)
    }

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

    private var photoCarouselHeight: CGFloat {
        UIScreen.main.bounds.height * 0.5
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
                if !isDuplicate {
                    highlights.append(item)
                }
            }
        }

        return Array(highlights.prefix(6))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // attach lifecycle hooks below via modifiers
            ScrollView {
                VStack(spacing: 0) {
                    heroPhotoCarousel
                    mainContent
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: RedfinScrollOffsetKey.self,
                            value: geo.frame(in: .named("redfinScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "redfinScroll")
            .onPreferenceChange(RedfinScrollOffsetKey.self) { value in
                scrollOffset = value
                let scrolled = -value
                let ctx: AskRedfinContextModel.Context
                if scrolled < photoCarouselHeight - 80 {
                    ctx = .detailHero
                } else if scrolled < photoCarouselHeight + 400 {
                    ctx = .detailPrice
                } else if scrolled < photoCarouselHeight + 1100 {
                    ctx = .detailFeatures
                } else {
                    ctx = .detailLifestyle
                }
                if askRedfinContext.context != ctx {
                    askRedfinContext.context = ctx
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)

            if !hideAskRedfinFAB {
                askRedfinFAB
                    .padding(.trailing, Theme.Spacing.md)
            }
        }
        .background(Theme.Colors.background)
        .onAppear { askRedfinContext.context = .detailHero }
        .onDisappear { askRedfinContext.context = .default }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(useZoomTransition)
        .toolbarBackground(scrollOffset < -(photoCarouselHeight - 100) ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if useZoomTransition {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(scrollOffset < -(photoCarouselHeight - 100) ? Color.primary : Color.white)
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                if scrollOffset < -(photoCarouselHeight - 100) {
                    Text(listing.address)
                        .font(.inter(15, .semibold))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { onToggleSave() } label: {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(isSaved ? .red : scrollOffset < -(photoCarouselHeight - 100) ? .primary : .white)
                }
                .sensoryFeedback(.selection, trigger: isSaved)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: listing.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(scrollOffset < -(photoCarouselHeight - 100) ? Color.primary : Color.white)
                }
            }
        }
        .toolbarColorScheme(scrollOffset < -(photoCarouselHeight - 100) ? nil : .dark, for: .navigationBar)
        .onAppear {
            homePrice = listing.formattedFullPrice
        }
    }

    // MARK: - Hero Photo Carousel

    private var heroPhotoCarousel: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(listing.photos.enumerated()), id: \.offset) { index, url in
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
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: photoCarouselHeight)

            VStack(spacing: Theme.Spacing.sm) {
                carouselDots
                mediaSegmentedControl
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(height: photoCarouselHeight)
        .clipShape(.rect)
    }

    private var carouselDots: some View {
        HStack(spacing: Theme.Spacing.xxs + 2) {
            ForEach(0..<listing.photos.count, id: \.self) { index in
                Circle()
                    .fill(index == currentPhotoIndex ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var mediaSegmentedControl: some View {
        HStack(spacing: 0) {
            mediaTabItem(icon: "play.fill", label: "Media", tab: 0)
            mediaTabItem(icon: "map.fill", label: "Map", tab: 1)
            mediaTabItem(icon: "cube.fill", label: "3D", tab: 2)
            mediaTabItem(icon: "binoculars.fill", label: "Street", tab: 3)
        }
        .padding(3)
        .adaptiveGlassSegment()
    }

    private func mediaTabItem(icon: String, label: String, tab: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMediaTab = tab
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.inter(12, .medium))
            }
            .foregroundStyle(selectedMediaTab == tab ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                selectedMediaTab == tab ? Color.white.opacity(0.2) : Color.clear,
                in: .capsule
            )
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: Theme.Container.spacing) {
            priceAndAddressSection

            rateSummarySection

            if !hideAskRedfinFAB {
                requestShowingSection
            }

            sectionContainer {
                propertyDetailsContent
            }

            sectionContainer {
                featureAndDescriptionContent
            }

            sectionContainer(accent: true) {
                ratePaymentContent
            }

            sectionContainer {
                takeTourContent
            }

            sectionContainer {
                askRedfinContent
            }

            sectionContainer {
                lifestyleContent
            }

            Color.clear.frame(height: 80)
        }
        .padding(.horizontal, Theme.Spacing.md)
    }

    // MARK: - Section Container

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

    // MARK: - Price & Address

    private var priceAndAddressSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(listing.formattedFullPrice)
                .font(Theme.Typography.heroNumber)
                .padding(.top, Theme.Spacing.lg)

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

    // MARK: - Rate Summary

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

    // MARK: - Request Showing

    private var requestShowingSection: some View {
        Button(action: {}) {
            Text("Request showing")
        }
        .buttonStyle(.primary)
    }

    // MARK: - Property Details Container Content (left-icon, right-info rows)

    private var propertyDetailsContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xl) {
                propertyDetailRow(icon: "house", value: listing.propertyType, label: "Property type")
                propertyDetailRow(icon: "calendar", value: "\(listing.yearBuilt)", label: "Year built")
                propertyDetailRow(icon: "arrow.up.left.and.arrow.down.right", value: listing.lotSize, label: "Lot size")
                propertyDetailRow(icon: "dollarsign.circle", value: "$\(listing.pricePerSqFt)", label: "Per sq. ft.")
                propertyDetailRow(icon: "chart.line.uptrend.xyaxis", value: listing.formattedFullPrice, label: "Redfin Estimate")
                propertyDetailRow(icon: "banknote", value: listing.hoaDues == "N/A" ? "$0" : listing.hoaDues, label: "HOA dues")
            }
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
                Text(value)
                    .font(Theme.Typography.secondaryBold)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Feature Highlights + Description Container

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

                Button(action: {}) {
                    Text("Full property details")
                }
                .buttonStyle(.secondary)
                .padding(.top, Theme.Spacing.xxs)
            }
        }
    }

    private func iconTagCell(icon: String, label: String, sublabel: String? = nil) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconTag.iconSize, weight: .medium))
                .foregroundStyle(Theme.IconTag.iconColor)

            TagView(text: label)

            if let sublabel {
                Text(sublabel)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func iconForTag(_ tag: String) -> String {
        let lowered = tag.lowercased()
        if lowered.contains("modern") || lowered.contains("fixture") { return "lightbulb" }
        if lowered.contains("island") || lowered.contains("kitchen") { return "frying.pan" }
        if lowered.contains("garage") { return "car" }
        if lowered.contains("patio") || lowered.contains("backyard") { return "tree" }
        if lowered.contains("bedroom") || lowered.contains("spacious") { return "bed.double" }
        if lowered.contains("closet") { return "door.left.hand.open" }
        if lowered.contains("pool") { return "figure.pool.swim" }
        if lowered.contains("view") { return "mountain.2" }
        if lowered.contains("fireplace") { return "fireplace" }
        if lowered.contains("solar") { return "sun.max" }
        if lowered.contains("smart") || lowered.contains("tech") { return "wifi" }
        if lowered.contains("hardwood") || lowered.contains("floor") { return "square.grid.3x3" }
        return "star.fill"
    }

    // MARK: - Rate/Payment Container Content

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

            Button(action: {}) {
                Text("Estimate my payment & rate")
            }
            .buttonStyle(.primary)

            Divider()

            checkmarkItems
        }
    }

    private var checkmarkItems: some View {
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
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(Theme.Typography.secondary)
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
                Rectangle()
                    .fill(Theme.Colors.Chart.blue)
                    .frame(width: max(piWidth, 2))
                Rectangle()
                    .fill(Theme.Colors.Chart.green)
                    .frame(width: max(taxWidth, 2))
                Rectangle()
                    .fill(Theme.Colors.Chart.amber)
                    .frame(width: max(insWidth, 2))
                if hoaDuesAmount > 0 {
                    Rectangle()
                        .fill(Theme.Colors.Chart.purple)
                        .frame(width: max(hoaWidth, 2))
                }
            }
        }
        .frame(height: 8)
        .clipShape(.rect(cornerRadius: 4))
    }

    // MARK: - Take a Tour Container Content

    private var takeTourContent: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Take a tour")
                .font(Theme.Typography.sectionTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            AsyncImage(url: URL(string: tourIllustrationURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 180)
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

    // MARK: - Ask Redfin Container Content

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

    // MARK: - Lifestyle Container Content

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

    // MARK: - Sticky Ask Redfin FAB

    private var askRedfinFAB: some View {
        GlassActionButton(icon: "sparkle", action: onAskRedfin, size: 52)
    }
}

private struct RedfinScrollOffsetKey: PreferenceKey {
    nonisolated static let defaultValue: CGFloat = 0
    nonisolated static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
