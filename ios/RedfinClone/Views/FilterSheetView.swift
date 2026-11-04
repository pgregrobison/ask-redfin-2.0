import SwiftUI
import MapKit

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ListingsViewModel

    @State private var propertyType: String = "Any"
    @State private var minSqFt: Int? = nil
    @State private var maxSqFt: Int? = nil
    @State private var minLot: Int? = nil
    @State private var maxLot: Int? = nil
    @State private var minYear: Int? = nil
    @State private var maxYear: Int? = nil
    @State private var hoaMax: Int? = nil
    @State private var minParking: Int = 0
    @State private var amenities: Set<String> = []

    @State private var searchService = LocationSearchService()
    @FocusState private var isLocationFocused: Bool

    private let propertyTypes = ["Any", "House", "Condo", "Townhouse", "Co-op", "Multi-family"]
    private let amenityOptions = ["Pool", "Garage", "A/C", "Fireplace", "Waterfront"]

    private let priceOptions: [(String, Int?)] = [
        ("No Min", nil), ("$200K", 200_000), ("$400K", 400_000), ("$600K", 600_000),
        ("$800K", 800_000), ("$1M", 1_000_000), ("$1.5M", 1_500_000),
        ("$2M", 2_000_000), ("$3M", 3_000_000), ("$5M", 5_000_000),
    ]

    private let maxPriceOptions: [(String, Int?)] = [
        ("No Max", nil), ("$500K", 500_000), ("$750K", 750_000), ("$1M", 1_000_000),
        ("$1.5M", 1_500_000), ("$2M", 2_000_000), ("$2.5M", 2_500_000),
        ("$3M", 3_000_000), ("$5M", 5_000_000), ("$10M", 10_000_000),
    ]

    private let minSqFtOptions: [(String, Int?)] = [
        ("No Min", nil), ("500", 500), ("750", 750), ("1,000", 1000),
        ("1,250", 1250), ("1,500", 1500), ("1,750", 1750), ("2,000", 2000),
        ("2,500", 2500), ("3,000", 3000), ("4,000", 4000),
    ]
    private let maxSqFtOptions: [(String, Int?)] = [
        ("No Max", nil), ("1,000", 1000), ("1,500", 1500), ("2,000", 2000),
        ("2,500", 2500), ("3,000", 3000), ("4,000", 4000), ("5,000", 5000),
        ("7,500", 7500), ("10,000", 10000),
    ]

    private let minLotOptions: [(String, Int?)] = [
        ("No Min", nil), ("2,000 sqft", 2000), ("5,000 sqft", 5000),
        ("¼ acre", 10890), ("½ acre", 21780), ("1 acre", 43560),
        ("2 acres", 87120), ("5 acres", 217800),
    ]
    private let maxLotOptions: [(String, Int?)] = [
        ("No Max", nil), ("5,000 sqft", 5000), ("¼ acre", 10890),
        ("½ acre", 21780), ("1 acre", 43560), ("2 acres", 87120),
        ("5 acres", 217800), ("10 acres", 435600),
    ]

    private let minYearOptions: [(String, Int?)] = [
        ("No Min", nil), ("1900", 1900), ("1940", 1940), ("1970", 1970),
        ("1990", 1990), ("2000", 2000), ("2010", 2010), ("2020", 2020),
    ]
    private let maxYearOptions: [(String, Int?)] = [
        ("No Max", nil), ("1970", 1970), ("1990", 1990), ("2000", 2000),
        ("2010", 2010), ("2020", 2020), ("2024", 2024),
    ]

    private let hoaOptions: [(String, Int?)] = [
        ("Any", nil), ("No HOA fee", 0), ("Up to $50/mo", 50),
        ("Up to $100/mo", 100), ("Up to $200/mo", 200),
        ("Up to $500/mo", 500), ("Up to $1,000/mo", 1000),
    ]

    private let controlHeight: CGFloat = 44
    private let tileHeight: CGFloat = 48
    private let controlRadius: CGFloat = 12

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    statusSegmentedControl
                    locationSection
                    priceSection
                    bedsSection
                    bathsSection
                    propertyTypeSection
                    sqFtSection
                    lotSection
                    yearSection
                    hoaSection
                    parkingSection
                    moreSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        resetAll()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                searchService.searchText = viewModel.locationName
            }
        }
    }

    // MARK: - Status

    private var statusSegmentedControl: some View {
        Picker("Listing status", selection: $viewModel.listingStatus) {
            ForEach(ListingStatus.allCases) { status in
                Text(status.rawValue).tag(status)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Location")

            HStack(spacing: Theme.Spacing.xs) {
                TextField("Search location", text: Binding(
                    get: { searchService.searchText },
                    set: { searchService.updateQuery($0) }
                ))
                .font(Theme.Typography.body)
                .focused($isLocationFocused)
                .submitLabel(.search)

                if !searchService.searchText.isEmpty {
                    Button {
                        searchService.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.ButtonSize.iconSize))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(height: controlHeight)
            .background(Theme.Colors.fill, in: .rect(cornerRadius: controlRadius))

            if !searchService.suggestions.isEmpty {
                suggestionsList
            }
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(searchService.suggestions, id: \.self) { suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: Theme.Spacing.lg))
                            .foregroundStyle(Theme.Colors.brandRed.opacity(0.85))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.inter(15, .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion != searchService.suggestions.last {
                    Divider().padding(.leading, Theme.Spacing.sm + 28)
                }
            }
        }
        .background(Theme.Colors.fill, in: .rect(cornerRadius: controlRadius))
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isLocationFocused = false
        Task {
            if let region = await searchService.search(for: suggestion) {
                viewModel.locationName = suggestion.title
                withAnimation(.easeInOut(duration: 0.5)) {
                    viewModel.mapPosition = .region(region)
                }
                searchService.clear()
                searchService.searchText = suggestion.title
            }
        }
    }

    // MARK: - Price

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Price")
            rangeDropdowns(
                minLabel: priceLabel(for: viewModel.filterMinPrice, fallback: "Enter min"),
                minIsPlaceholder: viewModel.filterMinPrice == nil,
                minOptions: priceOptions,
                minSelection: $viewModel.filterMinPrice,
                maxLabel: priceLabel(for: viewModel.filterMaxPrice, fallback: "Enter max"),
                maxIsPlaceholder: viewModel.filterMaxPrice == nil,
                maxOptions: maxPriceOptions,
                maxSelection: $viewModel.filterMaxPrice
            )
        }
    }

    private func priceLabel(for value: Int?, fallback: String) -> String {
        guard let value else { return fallback }
        if value >= 1_000_000 {
            let m = Double(value) / 1_000_000.0
            if m == m.rounded() { return "$\(Int(m))M" }
            return "$\(String(format: "%.1f", m))M"
        }
        return "$\(value / 1000)K"
    }

    // MARK: - Beds & Baths

    private var bedsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Beds")
            optionTiles(
                options: [0, 1, 2, 3, 4, 5],
                selection: $viewModel.filterMinBeds,
                labelForValue: { $0 == 0 ? "Any" : "\($0)+" }
            )
        }
    }

    private var bathsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Baths")
            optionTiles(
                options: [0, 1, 2, 3, 4],
                selection: $viewModel.filterMinBaths,
                labelForValue: { $0 == 0 ? "Any" : "\($0)+" }
            )
        }
    }

    // MARK: - Property type

    private var propertyTypeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Home type")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.xs)],
                spacing: Theme.Spacing.xs
            ) {
                ForEach(propertyTypes, id: \.self) { type in
                    let isSelected = propertyType == type
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            propertyType = type
                        }
                    } label: {
                        chipLabel(type, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Square feet / Lot / Year / HOA

    private var sqFtSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Square feet")
            rangeDropdowns(
                minLabel: minSqFt.map { "\(formatNumber($0)) sqft" } ?? "Min sqft",
                minIsPlaceholder: minSqFt == nil,
                minOptions: minSqFtOptions,
                minSelection: $minSqFt,
                maxLabel: maxSqFt.map { "\(formatNumber($0)) sqft" } ?? "Max sqft",
                maxIsPlaceholder: maxSqFt == nil,
                maxOptions: maxSqFtOptions,
                maxSelection: $maxSqFt
            )
        }
    }

    private var lotSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Lot size")
            rangeDropdowns(
                minLabel: lotLabel(minLot, fallback: "Min lot"),
                minIsPlaceholder: minLot == nil,
                minOptions: minLotOptions,
                minSelection: $minLot,
                maxLabel: lotLabel(maxLot, fallback: "Max lot"),
                maxIsPlaceholder: maxLot == nil,
                maxOptions: maxLotOptions,
                maxSelection: $maxLot
            )
        }
    }

    private func lotLabel(_ value: Int?, fallback: String) -> String {
        guard let value else { return fallback }
        if value >= 43560 {
            let acres = Double(value) / 43560.0
            if acres == acres.rounded() { return "\(Int(acres)) ac" }
            return "\(String(format: "%.2f", acres)) ac"
        }
        return "\(formatNumber(value)) sqft"
    }

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Year built")
            rangeDropdowns(
                minLabel: minYear.map(String.init) ?? "Min year",
                minIsPlaceholder: minYear == nil,
                minOptions: minYearOptions,
                minSelection: $minYear,
                maxLabel: maxYear.map(String.init) ?? "Max year",
                maxIsPlaceholder: maxYear == nil,
                maxOptions: maxYearOptions,
                maxSelection: $maxYear
            )
        }
    }

    private var hoaSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("HOA fee")
            singleDropdown(
                label: hoaLabel(hoaMax),
                isPlaceholder: hoaMax == nil,
                options: hoaOptions,
                selection: $hoaMax
            )
        }
    }

    private func hoaLabel(_ value: Int?) -> String {
        guard let value else { return "Any" }
        if value == 0 { return "No HOA fee" }
        return "Up to $\(formatNumber(value))/mo"
    }

    // MARK: - Parking

    private var parkingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("Parking spots")
            optionTiles(
                options: [0, 1, 2, 3, 4],
                selection: $minParking,
                labelForValue: { $0 == 0 ? "Any" : "\($0)+" }
            )
        }
    }

    // MARK: - More amenities

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionLabel("More")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: Theme.Spacing.xs)],
                spacing: Theme.Spacing.xs
            ) {
                ForEach(amenityOptions, id: \.self) { amenity in
                    let isSelected = amenities.contains(amenity)
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            if isSelected {
                                amenities.remove(amenity)
                            } else {
                                amenities.insert(amenity)
                            }
                        }
                    } label: {
                        chipLabel(amenity, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Shared building blocks

    private func rangeDropdowns(
        minLabel: String,
        minIsPlaceholder: Bool,
        minOptions: [(String, Int?)],
        minSelection: Binding<Int?>,
        maxLabel: String,
        maxIsPlaceholder: Bool,
        maxOptions: [(String, Int?)],
        maxSelection: Binding<Int?>
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            singleDropdown(
                label: minLabel,
                isPlaceholder: minIsPlaceholder,
                options: minOptions,
                selection: minSelection
            )

            Text("–")
                .font(Theme.Typography.secondary)
                .foregroundStyle(.tertiary)

            singleDropdown(
                label: maxLabel,
                isPlaceholder: maxIsPlaceholder,
                options: maxOptions,
                selection: maxSelection
            )
        }
    }

    private func singleDropdown(
        label: String,
        isPlaceholder: Bool,
        options: [(String, Int?)],
        selection: Binding<Int?>
    ) -> some View {
        Menu {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    selection.wrappedValue = option.1
                } label: {
                    HStack {
                        Text(option.0)
                        if selection.wrappedValue == option.1 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(label)
                    .font(Theme.Typography.body)
                    .foregroundStyle(isPlaceholder ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .background(Theme.Colors.fill, in: .rect(cornerRadius: controlRadius))
        }
    }

    private func optionTiles(options: [Int], selection: Binding<Int>, labelForValue: @escaping (Int) -> String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(options, id: \.self) { value in
                let isSelected = selection.wrappedValue == value
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        selection.wrappedValue = value
                    }
                } label: {
                    Text(labelForValue(value))
                        .font(.inter(15, isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: tileHeight)
                        .background(
                            isSelected ? AnyShapeStyle(Color(.label)) : AnyShapeStyle(Theme.Colors.fill),
                            in: .rect(cornerRadius: controlRadius)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chipLabel(_ text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.inter(15, isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .padding(.horizontal, Theme.Spacing.sm)
            .frame(maxWidth: .infinity)
            .frame(height: tileHeight)
            .background(
                isSelected ? AnyShapeStyle(Color(.label)) : AnyShapeStyle(Theme.Colors.fill),
                in: .rect(cornerRadius: controlRadius)
            )
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.secondary)
            .foregroundStyle(.primary)
    }

    private func formatNumber(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func resetAll() {
        viewModel.filterMinPrice = nil
        viewModel.filterMaxPrice = nil
        viewModel.filterMinBeds = 0
        viewModel.filterMinBaths = 0
        propertyType = "Any"
        minSqFt = nil
        maxSqFt = nil
        minLot = nil
        maxLot = nil
        minYear = nil
        maxYear = nil
        hoaMax = nil
        minParking = 0
        amenities = []
    }
}
