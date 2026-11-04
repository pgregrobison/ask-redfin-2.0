import SwiftUI

/// The iOS Vision Filters sheet: view, sort, criteria, price, home type,
/// beds, baths, square feet, HOA and features. Changes apply live; the
/// footer shows the live count.
struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ListingsViewModel

    private static let sqftMins: [(Int, String)] = [(0, "No min"), (750, "750"), (1000, "1,000"), (1250, "1,250"), (1500, "1,500"), (2000, "2,000")]
    private static let sqftMaxes: [(Int, String)] = [(0, "No max"), (1000, "1,000"), (1250, "1,250"), (1500, "1,500"), (2000, "2,000"), (3000, "3,000")]
    private static let hoaOptions: [(Int, String)] = [(0, "Any"), (-1, "No HOA"), (250, "Up to $250/month"), (500, "Up to $500/month")]

    private var filters: Binding<HomeFilters> { $viewModel.search.filters }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    section { viewToggle }
                    section { sortChips }
                    if !viewModel.search.criteria.isEmpty {
                        section { criteriaChips }
                    }
                    section {
                        FilterGroup("Price range") {
                            PriceRangeControl(minPrice: filters.minPrice, maxPrice: filters.maxPrice, listings: viewModel.listings)
                        }
                    }
                    section {
                        FilterGroup("Home type") {
                            ChipToggleRow(options: HomeCatalog.homeTypes, selection: filters.types)
                        }
                    }
                    section { RoomsControl(beds: filters.beds, baths: filters.baths) }
                    section { squareFeet }
                    section {
                        FilterGroup("HOA fees") {
                            menuPicker(Self.hoaOptions, selection: filters.hoa)
                        }
                    }
                    section(divider: false) {
                        FilterGroup("Features") {
                            ChipToggleRow(options: HomeCatalog.features, selection: filters.features)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
        .tint(Nova.Color.text)
    }

    // MARK: Sections

    private func section<Content: View>(divider: Bool = true, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content().padding(24)
            if divider { Rectangle().fill(Nova.Color.border).frame(height: 1) }
        }
    }

    private var viewToggle: some View {
        FilterGroup("View") {
            Picker("View", selection: Binding(
                get: { viewModel.showListView },
                set: { list in
                    viewModel.dismissOverlay()
                    viewModel.showListView = list
                    dismiss()
                }
            )) {
                Label("Map", systemImage: "map").tag(false)
                Label("List", systemImage: "list.bullet").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private var sortChips: some View {
        FilterGroup("Sort by") {
            FlowLayout(spacing: 8) {
                ForEach(sortOptions, id: \.0) { sort, title in
                    NovaChip(title: title, isSelected: viewModel.search.sort == sort, style: .outline) {
                        viewModel.search.sort = sort
                    }
                }
            }
        }
    }

    private var sortOptions: [(SearchSort, String)] {
        var out = [SearchSort.match, .priceLow, .priceHigh, .sqft].map { ($0, $0.title) }
        if let a = viewModel.activeAnalysis { out.append((.analysis, a.sortTitle)) }
        return out
    }

    private var criteriaChips: some View {
        FilterGroup("What matters to you", subtitle: "Homes are ranked by how many of these they match. Add more from the search bar.") {
            FlowLayout(spacing: 8) {
                ForEach(viewModel.search.criteria, id: \.self) { c in
                    Button {
                        withAnimation(Nova.Motion.easeOut()) {
                            _ = viewModel.changeSearch { s in
                                s.criteria.removeAll { $0 == c }
                                s.modes[c] = nil
                                s.disabled.remove(c)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.search.pillLabel(for: c)).font(Nova.Typography.label14)
                            NovaIcon("close", size: 16)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .foregroundStyle(Nova.Color.text)
                        .background(Nova.Color.overlay, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(c)")
                }
            }
        }
    }

    private var squareFeet: some View {
        FilterGroup("Square feet") {
            HStack(spacing: 12) {
                menuPicker(Self.sqftMins, selection: filters.minSqft)
                Rectangle().fill(Nova.Color.borderEmphasis).frame(width: 8, height: 1)
                menuPicker(Self.sqftMaxes, selection: filters.maxSqft)
            }
        }
    }

    private func menuPicker(_ options: [(Int, String)], selection: Binding<Int>) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(options, id: \.0) { value, title in Text(title).tag(value) }
            }
        } label: {
            HStack {
                Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? options[0].1)
                    .font(Nova.Typography.body16)
                Spacer()
                NovaIcon("expand_more", size: 16)
            }
            .foregroundStyle(Nova.Color.text)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Clear all") {
                withAnimation(Nova.Motion.easeOut()) {
                    _ = viewModel.changeSearch { s in
                        s.filters = HomeFilters()
                        s.sort = .match
                    }
                }
            }
            .buttonStyle(.novaLink)
            Spacer()
            Button("Show \(viewModel.rankedResults.count) homes") { dismiss() }
                .buttonStyle(.nova(.primary))
                .contentTransition(.numericText())
                .animation(Nova.Motion.easeOut(), value: viewModel.rankedResults.count)
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 16))
        .background(Nova.Color.bgPrimary)
        .overlay(alignment: .top) { Rectangle().fill(Nova.Color.border).frame(height: 1) }
    }
}
