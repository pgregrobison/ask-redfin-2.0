import SwiftUI

/// The iOS Vision Filters sheet as a native grouped Form: view and sort,
/// criteria (with how each one counts), price, rooms, home type, size, HOA
/// and features. Changes apply live; the footer shows the live count.
struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ListingsViewModel

    private static let sqftMins: [(Int, String)] = [(0, "No min"), (750, "750"), (1000, "1,000"), (1250, "1,250"), (1500, "1,500"), (2000, "2,000")]
    private static let sqftMaxes: [(Int, String)] = [(0, "No max"), (1000, "1,000"), (1250, "1,250"), (1500, "1,500"), (2000, "2,000"), (3000, "3,000")]
    private static let hoaOptions: [(Int, String)] = [(0, "Any"), (-1, "No HOA"), (250, "Up to $250/month"), (500, "Up to $500/month")]

    private var filters: Binding<HomeFilters> { $viewModel.search.filters }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("View", selection: viewBinding) {
                        Text("Map").tag(false)
                        Text("List").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    Picker("Sort by", selection: $viewModel.search.sort) {
                        ForEach(sortOptions, id: \.0) { sort, title in Text(title).tag(sort) }
                    }
                }

                if !viewModel.search.criteria.isEmpty {
                    Section {
                        ForEach(viewModel.search.criteria, id: \.self) { c in
                            Picker(viewModel.search.pillLabel(for: c), selection: modeBinding(c)) {
                                Text("Nice to have").tag(CriterionMode.nice)
                                Text("Must have").tag(CriterionMode.must)
                                Text("Dealbreaker").tag(CriterionMode.deal)
                            }
                        }
                        .onDelete { offsets in
                            let removed = offsets.map { viewModel.search.criteria[$0] }
                            viewModel.changeSearch { s in
                                s.criteria.removeAll { removed.contains($0) }
                                removed.forEach { s.modes[$0] = nil; s.disabled.remove($0) }
                            }
                        }
                    } header: {
                        Text("What matters to you")
                    } footer: {
                        Text("Homes are ranked by how many of these they match. Swipe to remove one, or add more from the search bar.")
                    }
                }

                Section("Price range") {
                    PriceRangeControl(minPrice: filters.minPrice, maxPrice: filters.maxPrice, listings: viewModel.listings)
                        .padding(.vertical, 8)
                }

                Section {
                    RoomsControl(beds: filters.beds, baths: filters.baths)
                        .padding(.vertical, 4)
                    NavigationLink {
                        HomeTypeChecklist(types: filters.types)
                    } label: {
                        LabeledContent("Home type", value: homeTypeSummary)
                    }
                    Picker("Min square feet", selection: filters.minSqft) {
                        ForEach(Self.sqftMins, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Max square feet", selection: filters.maxSqft) {
                        ForEach(Self.sqftMaxes, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("HOA fees", selection: filters.hoa) {
                        ForEach(Self.hoaOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }

                Section("Features") {
                    ForEach(HomeCatalog.features, id: \.self) { feature in
                        Toggle(feature, isOn: featureBinding(feature))
                            .tint(Nova.Color.green600)
                    }
                }
            }
            .font(Nova.Typography.body16)
            .tint(Nova.Color.gray800)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { closeButton }
            }
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    // MARK: Bindings

    private var viewBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showListView },
            set: { list in
                viewModel.dismissOverlay()
                viewModel.showListView = list
                dismiss()
            }
        )
    }

    private var sortOptions: [(SearchSort, String)] {
        var out = [SearchSort.match, .priceLow, .priceHigh, .sqft].map { ($0, $0.title) }
        if let a = viewModel.activeAnalysis { out.append((.analysis, a.sortTitle)) }
        return out
    }

    private func modeBinding(_ c: String) -> Binding<CriterionMode> {
        Binding(
            get: { viewModel.search.mode(of: c) },
            set: { mode in viewModel.changeSearch { $0.modes[c] = mode == .nice ? nil : mode } }
        )
    }

    private func featureBinding(_ feature: String) -> Binding<Bool> {
        Binding(
            get: { viewModel.search.filters.features.contains(feature) },
            set: { on in
                viewModel.search.filters.features.removeAll { $0 == feature }
                if on { viewModel.search.filters.features.append(feature) }
            }
        )
    }

    private var homeTypeSummary: String {
        let t = viewModel.search.filters.types
        return t.isEmpty ? "Any" : t.joined(separator: ", ")
    }

    // MARK: Chrome

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .close) { dismiss() } label: { NovaIcon("close", size: 20) }
        } else {
            Button { dismiss() } label: { NovaIcon("close", size: 20) }
                .accessibilityLabel("Close")
        }
    }

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
                .buttonStyle(.nova(.primary, size: .large))
                .contentTransition(.numericText())
                .animation(Nova.Motion.easeOut(), value: viewModel.rankedResults.count)
        }
        .padding(EdgeInsets(top: 12, leading: 24, bottom: 8, trailing: 16))
        .background(.bar)
    }
}

/// Native multi-select checklist for home types.
private struct HomeTypeChecklist: View {
    @Binding var types: [String]

    var body: some View {
        List {
            Section {
                ForEach(HomeCatalog.homeTypes, id: \.self) { type in
                    Button {
                        if let i = types.firstIndex(of: type) { types.remove(at: i) } else { types.append(type) }
                    } label: {
                        HStack {
                            Text(type).foregroundStyle(Nova.Color.text)
                            Spacer()
                            if types.contains(type) {
                                NovaIcon("check", size: 20).foregroundStyle(Nova.Color.text)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(types.contains(type) ? .isSelected : [])
                }
            } footer: {
                Text("Leave all unchecked to see every home type.")
            }
        }
        .font(Nova.Typography.body16)
        .navigationTitle("Home type")
        .navigationBarTitleDisplayMode(.inline)
    }
}
