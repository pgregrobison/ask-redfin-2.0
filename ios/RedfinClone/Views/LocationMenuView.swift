import SwiftUI
import MapKit

struct LocationMenuView: View {
    @Bindable var viewModel: ListingsViewModel
    @Bindable var searchService: LocationSearchService
    let onClose: () -> Void
    let onOpenFilter: () -> Void

    @FocusState private var isSearchFocused: Bool

    private let priceOptions: [(String, Int?)] = [
        ("No Min", nil),
        ("$200K", 200_000),
        ("$400K", 400_000),
        ("$600K", 600_000),
        ("$800K", 800_000),
        ("$1M", 1_000_000),
        ("$1.5M", 1_500_000),
        ("$2M", 2_000_000),
        ("$3M", 3_000_000),
        ("$5M", 5_000_000),
    ]

    private let maxPriceOptions: [(String, Int?)] = [
        ("No Max", nil),
        ("$500K", 500_000),
        ("$750K", 750_000),
        ("$1M", 1_000_000),
        ("$1.5M", 1_500_000),
        ("$2M", 2_000_000),
        ("$2.5M", 2_500_000),
        ("$3M", 3_000_000),
        ("$5M", 5_000_000),
        ("$10M", 10_000_000),
    ]

    private let controlHeight: CGFloat = 44
    private let controlRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            statusSegmentedControl
            locationSection
            priceSection
            bedsSection
            bathsSection
            actionButtons

            if !searchService.suggestions.isEmpty {
                Divider().padding(.horizontal, Theme.Spacing.md)
                suggestionslist
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .onAppear {
            searchService.searchText = viewModel.locationName
        }
    }

    // MARK: - Status segmented control

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
            Text("Location")
                .font(Nova.Typography.body14)
                .foregroundStyle(.primary)

            HStack(spacing: Theme.Spacing.xs) {
                TextField("Search location", text: Binding(
                    get: { searchService.searchText },
                    set: { searchService.updateQuery($0) }
                ))
                .font(Theme.Typography.body)
                .focused($isSearchFocused)
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
        }
    }

    // MARK: - Price

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Price")
                .font(Nova.Typography.body14)
                .foregroundStyle(.primary)

            HStack(spacing: Theme.Spacing.xs) {
                priceDropdown(
                    label: priceLabel(for: viewModel.filterMinPrice, fallback: "Enter min"),
                    isPlaceholder: viewModel.filterMinPrice == nil,
                    options: priceOptions,
                    selection: $viewModel.filterMinPrice
                )

                Text("–")
                    .font(Nova.Typography.body14)
                    .foregroundStyle(.tertiary)

                priceDropdown(
                    label: priceLabel(for: viewModel.filterMaxPrice, fallback: "Enter max"),
                    isPlaceholder: viewModel.filterMaxPrice == nil,
                    options: maxPriceOptions,
                    selection: $viewModel.filterMaxPrice
                )
            }
        }
    }

    private func priceDropdown(label: String, isPlaceholder: Bool, options: [(String, Int?)], selection: Binding<Int?>) -> some View {
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

    private func priceLabel(for value: Int?, fallback: String) -> String {
        guard let value else { return fallback }
        if value >= 1_000_000 {
            let m = Double(value) / 1_000_000.0
            if m == m.rounded() {
                return "$\(Int(m))M"
            }
            return "$\(String(format: "%.1f", m))M"
        }
        return "$\(value / 1000)K"
    }

    // MARK: - Beds & Baths

    private var bedsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Beds")
                .font(Nova.Typography.body14)
                .foregroundStyle(.primary)

            optionTiles(
                options: [0, 1, 2, 3, 4, 5],
                selection: $viewModel.filterMinBeds,
                labelForValue: { $0 == 0 ? "Any" : "\($0)+" }
            )
        }
    }

    private var bathsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Baths")
                .font(Nova.Typography.body14)
                .foregroundStyle(.primary)

            optionTiles(
                options: [0, 1, 2, 3, 4],
                selection: $viewModel.filterMinBaths,
                labelForValue: { $0 == 0 ? "Any" : "\($0)+" }
            )
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
                        .font(.nova(14, isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: controlHeight + 4)
                        .background(
                            isSelected ? AnyShapeStyle(Color(.label)) : AnyShapeStyle(Theme.Colors.fill),
                            in: .rect(cornerRadius: controlRadius)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button {
                onOpenFilter()
            } label: {
                actionLabel(systemImage: "slider.horizontal.3", title: "Filters")
            }
            .buttonStyle(.plain)

            Button {} label: {
                actionLabel(systemImage: "bookmark", title: "Save search")
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Theme.Spacing.xxs)
    }

    private func actionLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: Theme.IconSize.small, weight: .semibold))
            Text(title)
                .font(Nova.Typography.label14)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: controlHeight + 4)
        .background(Theme.Colors.fill, in: .capsule)
    }

    // MARK: - Search suggestions

    private var suggestionslist: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
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
                                    .font(Nova.Typography.label14)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(Nova.Typography.caption12)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs + 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 240)
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        isSearchFocused = false
        Task {
            if let region = await searchService.search(for: suggestion) {
                viewModel.locationName = suggestion.title
                withAnimation(.easeInOut(duration: 0.5)) {
                    viewModel.mapPosition = .region(region)
                }
                searchService.clear()
                searchService.searchText = suggestion.title
                onClose()
            }
        }
    }
}
