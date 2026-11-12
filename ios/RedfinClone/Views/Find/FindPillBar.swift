import SwiftUI

/// The iOS Vision top bar: one scrolling row of Filters, Location, Price,
/// Beds & baths, then the criteria, refinements and analysis as toggle pills.
/// Glass over the map; flat on the warm canvas in list view.
struct FindPillBar: View {
    @Bindable var viewModel: ListingsViewModel

    @State private var showFilters = false
    @State private var showLocation = false
    @State private var showPrice = false
    @State private var showRooms = false

    private var onMap: Bool { !viewModel.showListView }
    private var s: SearchState { viewModel.search }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                // Outside the glass group so its count badge draws above the pills.
                filtersButton
                NovaGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                pill(s.locationPillLabel, chevron: showLocation) { showLocation = true }
                    .popover(isPresented: $showLocation) {
                        LocationSearchPopover(viewModel: viewModel)
                            .presentationCompactAdaptation(.popover)
                    }
                if s.exposed.contains("price") {
                    pill(s.priceLabel ?? "Price", chevron: showPrice) { showPrice = true }
                        .popover(isPresented: $showPrice) {
                            StructuredFilterPopover(viewModel: viewModel, kind: .price)
                                .presentationCompactAdaptation(.popover)
                        }
                }
                if s.exposed.contains("rooms") {
                    pill(s.roomsLabel ?? "Beds & baths", chevron: showRooms) { showRooms = true }
                        .popover(isPresented: $showRooms) {
                            StructuredFilterPopover(viewModel: viewModel, kind: .rooms)
                                .presentationCompactAdaptation(.popover)
                        }
                }
                if !s.criteria.isEmpty || !s.refinements.isEmpty || s.analysis != nil {
                    Capsule()
                        .fill(Nova.Color.gray800.opacity(0.32))
                        .frame(width: 2, height: 20)
                        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                        .accessibilityHidden(true)
                }
                ForEach(s.criteria, id: \.self) { criterionPill($0) }
                ForEach(s.refinements) { r in
                    togglePill(r.label, isOn: r.isOn) {
                        viewModel.changeSearch { st in
                            if let i = st.refinements.firstIndex(where: { $0.id == r.id }) { st.refinements[i].isOn.toggle() }
                        }
                    }
                }
                if let a = s.analysis, let def = HomeAnalyses.lookup(a.key) {
                    analysisPill(def, isOn: a.isOn)
                }
                }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .animation(Nova.Motion.easeOut(), value: s.criteria)
            .animation(Nova.Motion.easeOut(), value: s.refinements)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .padding(.top, 2)
        .padding(.bottom, onMap ? 0 : 4)
        .background {
            if !onMap {
                Nova.Color.canvas
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) { Rectangle().fill(Nova.Color.border).frame(height: 1) }
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheetView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Pills

    private var filtersButton: some View {
        Button { showFilters = true } label: {
            NovaIcon("filter_handles", size: 20)
                .foregroundStyle(Nova.Color.text)
                .frame(width: 32, height: 32)
                .modifier(PillChrome(onMap: onMap, isOn: true, shape: Circle()))
                .contentShape(Circle())
        }
        .buttonStyle(PillPressStyle(onMap: onMap, shape: Circle()))
        .overlay(alignment: .topTrailing) {
            let n = s.activeFilterCount
            if n > 0 {
                Text("\(n)")
                    .font(.novaFixed(11, .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color(white: 0.067), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    .offset(x: 6, y: -6)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityLabel(s.activeFilterCount > 0 ? "Filters, \(s.activeFilterCount) applied" : "Filters")
        .padding(.trailing, 4)
        .zIndex(1)
    }

    private func pill(_ title: String, chevron open: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(Nova.Typography.label14).lineLimit(1)
                NovaIcon(open ? "expand_less" : "expand_more", size: 16)
            }
            .foregroundStyle(Nova.Color.text)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .frame(height: 32)
            .modifier(PillChrome(onMap: onMap, isOn: true, shape: Capsule()))
            .contentShape(Capsule())
        }
        .buttonStyle(PillPressStyle(onMap: onMap, shape: Capsule()))
    }

    private func togglePill(_ title: String, isOn: Bool, trailing: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isOn {
                    NovaIcon("check", size: 16)
                } else {
                    Circle().strokeBorder(Nova.Color.gray400, lineWidth: 1.5).frame(width: 12, height: 12).padding(2)
                }
                Text(title).font(Nova.Typography.label14).lineLimit(1)
                if let trailing {
                    Text(trailing).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                }
            }
            .foregroundStyle(isOn ? Nova.Color.text : Nova.Color.gray700)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .modifier(PillChrome(onMap: onMap, isOn: isOn, shape: Capsule()))
            .contentShape(Capsule())
        }
        .buttonStyle(PillPressStyle(onMap: onMap, shape: Capsule()))
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Toggles this filter")
    }

    private func criterionPill(_ c: String) -> some View {
        let mode = s.mode(of: c)
        return togglePill(s.pillLabel(for: c), isOn: !s.disabled.contains(c), trailing: mode == .must ? "Must" : nil) {
            viewModel.changeSearch { st in
                if st.disabled.contains(c) { st.disabled.remove(c) } else { st.disabled.insert(c) }
            }
        }
        // Long-press sets how it counts (the prototype's unwired mode sheet).
        // Long-press sets how it counts (the prototype's unwired mode sheet).
        .contextMenu {
            Picker("How “\(c)” counts", selection: Binding(
                get: { s.mode(of: c) },
                set: { mode in
                    viewModel.changeSearch { st in
                        st.modes[c] = mode == .nice ? nil : mode
                        st.disabled.remove(c)
                    }
                }
            )) {
                Text("Nice to have\nCounts toward the match score").tag(CriterionMode.nice)
                Text("Must have\nHides homes that don’t mention it").tag(CriterionMode.must)
                Text("Dealbreaker\nHides homes that mention it").tag(CriterionMode.deal)
            }
            .pickerStyle(.inline)
            Button(role: .destructive) {
                withAnimation(Nova.Motion.easeOut()) {
                    _ = viewModel.changeSearch { st in
                        st.criteria.removeAll { $0 == c }
                        st.modes[c] = nil
                        st.disabled.remove(c)
                    }
                }
            } label: {
                Label { Text("Remove") } icon: { Image("Nova/delete") }
            }
        }
    }

    private func analysisPill(_ def: HomeAnalysis, isOn: Bool) -> some View {
        Button {
            viewModel.changeSearch { st in
                st.analysis?.isOn.toggle()
                if st.analysis?.isOn == true { st.sort = .analysis } else if st.sort == .analysis { st.sort = .match }
            }
        } label: {
            HStack(spacing: 6) {
                Group {
                    if isOn { Circle().fill(HomeAnalyses.rampGradient) }
                    else { Circle().strokeBorder(Nova.Color.gray400, lineWidth: 1.5) }
                }
                .frame(width: 12, height: 12)
                Text(def.pill).font(Nova.Typography.label14).lineLimit(1)
            }
            .foregroundStyle(isOn ? Nova.Color.text : Nova.Color.gray700)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .modifier(PillChrome(onMap: onMap, isOn: isOn, shape: Capsule()))
            .contentShape(Capsule())
        }
        .buttonStyle(PillPressStyle(onMap: onMap, shape: Capsule()))
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

/// Pill surface: native Liquid Glass over the map (clear glass when off),
/// white with a hairline on the list canvas.
private struct PillChrome<S: InsettableShape>: ViewModifier {
    let onMap: Bool
    let isOn: Bool
    let shape: S

    func body(content: Content) -> some View {
        if onMap {
            content.novaGlass(in: shape, interactive: true, clear: !isOn)
        } else {
            content.background {
                shape.fill(isOn ? Nova.Color.bgPrimary : Color.clear)
                    .overlay(shape.strokeBorder(isOn ? Nova.Color.border : Nova.Color.borderEmphasis, lineWidth: 1))
            }
        }
    }
}

/// Interactive glass gives its own press response on the map; the flat
/// list pills use Nova's press wash.
private struct PillPressStyle<S: Shape>: ButtonStyle {
    let onMap: Bool
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        if onMap {
            configuration.label
        } else {
            NovaPressWashStyle(shape: shape).makeBody(configuration: configuration)
        }
    }
}

// MARK: - Location popover

/// Native searchable list of places; tap to add or remove an area (the
/// last one can't be removed). Order freezes while open.
struct LocationSearchPopover: View {
    @Bindable var viewModel: ListingsViewModel
    @State private var query = ""
    @State private var frozenOrder: [String] = []

    private var places: [SearchRegions.Place] {
        let all = SearchRegions.shared.places
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            return all.filter { $0.name.lowercased().contains(q) || $0.kind.lowercased().contains(q) }
        }
        return frozenOrder.compactMap { n in all.first { $0.name == n } }
    }

    var body: some View {
        NavigationStack {
            List(places, id: \.name) { place in row(place) }
                .listStyle(.plain)
                .overlay {
                    if places.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .searchable(text: $query,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Add a city, neighborhood, ZIP or school")
                .navigationTitle("Search area")
                .navigationBarTitleDisplayMode(.inline)
        }
        .font(Nova.Typography.body16)
        .frame(width: 360, height: 440)
        .onAppear {
            let selected = viewModel.search.locations
            let rest = SearchRegions.shared.places.map(\.name).filter { !selected.contains($0) }
            frozenOrder = Array((selected + rest).prefix(max(6, selected.count)))
        }
    }

    private func row(_ place: SearchRegions.Place) -> some View {
        let isOn = viewModel.search.locations.contains(place.name)
        return Button {
            toggle(place.name)
        } label: {
            HStack(spacing: 12) {
                NovaIcon(place.icon, size: 24)
                    .frame(width: 40, height: 40)
                    .background(Nova.Color.bgTertiary, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
                VStack(alignment: .leading, spacing: 0) {
                    Text(place.name).font(Nova.Typography.label16)
                    Text(place.kind).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                }
                Spacer()
                if isOn { NovaIcon("check", size: 20) }
            }
            .foregroundStyle(Nova.Color.text)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ name: String) {
        let current = viewModel.search.locations
        if current.contains(name) {
            guard current.count > 1 else { return }
            viewModel.changeSearch { $0.locations.removeAll { $0 == name } }
        } else {
            viewModel.changeSearch { $0.locations = SearchRegions.shared.adding(name, to: current) }
        }
    }
}

// MARK: - Price / Beds & baths popover

struct StructuredFilterPopover: View {
    enum Kind { case price, rooms }

    @Bindable var viewModel: ListingsViewModel
    let kind: Kind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch kind {
            case .price:
                FilterGroup("Price") {
                    PriceRangeControl(minPrice: $viewModel.search.filters.minPrice,
                                      maxPrice: $viewModel.search.filters.maxPrice,
                                      listings: viewModel.listings)
                }
            case .rooms:
                RoomsControl(beds: $viewModel.search.filters.beds, baths: $viewModel.search.filters.baths)
            }
            HStack {
                Button("Clear") {
                    switch kind {
                    case .price: viewModel.changeSearch { $0.filters.minPrice = 0; $0.filters.maxPrice = 0 }
                    case .rooms: viewModel.changeSearch { $0.filters.beds = 0; $0.filters.baths = 0 }
                    }
                }
                .buttonStyle(.novaLink)
                Spacer()
                Button("Show \(viewModel.rankedResults.count) homes") { dismiss() }
                    .buttonStyle(.nova(.primary, size: .small))
                    .contentTransition(.numericText())
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
