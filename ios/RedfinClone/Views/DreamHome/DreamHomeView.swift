import SwiftUI

/// The iOS Vision "My home" tab: your dream home, built from and written
/// back to the search. Sections: where, budget, must-haves, bonus points,
/// looks, can't-haves and suggestions, plus "Find homes that match".
struct DreamHomeView: View {
    @Bindable var session: AskSession
    @State private var editing: Set<SearchState.DreamBucket> = []
    @State private var adding: SearchState.DreamBucket?
    @State private var draft = ""
    @State private var addingPlace = false
    @State private var calculating = false
    @State private var showInspiration = false
    @State private var sorterItems: [DreamRecommendation]?
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var dropTarget: SearchState.DreamBucket?
    @State private var appeared = false
    @FocusState private var addFocused: Bool

    private var listings: ListingsViewModel { session.listings }
    private var s: SearchState { listings.search }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header.rise(appeared, 0)
                section("It must be in") { locations }.rise(appeared, 0.09)
                section("I can spend") { buyingPower }.rise(appeared, 0.18)
                section("It must have") { bucket(.must, s.dreamMustHaves) }.rise(appeared, 0.3)
                section("Bonus points if it has") { bucket(.nice, s.dreamNiceToHaves) }.rise(appeared, 0.3)
                section("It looks like") { inspiration }.rise(appeared, 0.36)
                section("It can't have") { bucket(.deal, s.dreamDealBreakers) }.rise(appeared, 0.36)
                section("Maybe it also has") { suggestions }.rise(appeared, 0.45)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 96)
        }
        .background(Nova.Color.bgPrimary)
        .overlay(alignment: .bottomTrailing) { findButton }
        .overlay(alignment: .bottom) { toastView }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation { appeared = true } }
        .sheet(isPresented: $showInspiration) { InspirationPicker(session: session, onAdded: { n in showToast("Added \(n == 1 ? "1 photo" : "\(n) photos") to inspiration") }) }
        .fullScreenCover(item: Binding(get: { sorterItems.map { SorterDeck(items: $0) } }, set: { sorterItems = $0?.items })) { deck in
            DreamSorterView(items: deck.items) { result in
                listings.changeSearch { st in
                    for (bucket, items) in result { for r in items { st.addDream(r.criterion, to: bucket) } }
                }
                let n = result.values.reduce(0) { $0 + $1.count }
                sorterItems = nil
                showToast(n == 1 ? "Saved 1 preference" : "Saved \(n) preferences")
            } onClose: { sorterItems = nil }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "I'm buying my dream home someday ▾"
            (Text("I’m buying my ") + Text(s.dream.name.replacingRx("^(?i)my ", with: "").lowercased()))
                .font(.nova(28, .medium)).tracking(-0.6).foregroundStyle(Nova.Color.text)
            Menu {
                Picker("When", selection: dreamBinding(\.timeline)) {
                    ForEach(DreamExtras.Timeline.allCases, id: \.self) { t in
                        if let d = t.detail { Text(t.label).tag(t); Text(d) } else { Text(t.label).tag(t) }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(s.dream.timeline.label).underline(color: Nova.Color.gray300)
                    NovaIcon("expand_more", size: 22).foregroundStyle(Nova.Color.gray600)
                }
                .font(.nova(28, .medium)).tracking(-0.6).foregroundStyle(Nova.Color.text)
            }
            .padding(.top, -12)
            HStack(alignment: .top, spacing: 12) {
                Text("Redfin learns from everything you browse, but only what you approve lives here.")
                    .font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                Spacer(minLength: 0)
                Menu {
                    Picker("Dream home alerts", selection: dreamBinding(\.alerts)) {
                        ForEach(DreamExtras.Alerts.allCases, id: \.self) { a in
                            Label { Text(a.title); Text(a.detail) } icon: { Image("Nova/" + alertIcon(a)) }.tag(a)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label { Text(s.dream.alerts.title) } icon: { NovaIcon(alertIcon(s.dream.alerts), size: 18) }
                        .font(.nova(13, .medium)).foregroundStyle(Nova.Color.text)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Nova.Color.bgSecondary, in: Capsule())
                }
                .accessibilityLabel("Dream home alerts: \(s.dream.alerts.title)")
            }
        }
    }

    private func alertIcon(_ a: DreamExtras.Alerts) -> String {
        switch a { case .instant: "notifications_active"; case .daily: "notifications"; case .off: "notifications_off" }
    }

    // MARK: Locations

    private var locations: some View {
        FlowLayout(spacing: 8) {
            ForEach(s.locations, id: \.self) { loc in
                HStack(spacing: 6) {
                    NovaIcon("location", size: 14).foregroundStyle(Nova.Color.gray600)
                    Text(loc).font(Nova.Typography.label14)
                    if s.locations.count > 1 {
                        circleButton("close", label: "Remove \(loc)") {
                            listings.changeSearch { $0.locations.removeAll { $0 == loc } }
                        }
                    }
                }
                .padding(.leading, 12).padding(.trailing, s.locations.count > 1 ? 3 : 12)
                .modifier(PillChrome())
            }
            addPill(s.locations.isEmpty ? "Add place" : "Add nearby place") { addingPlace = true }
                .popover(isPresented: $addingPlace) {
                    LocationSearchPopover(viewModel: listings).presentationCompactAdaptation(.popover)
                }
        }
        .modifier(Tray())
    }

    // MARK: Buying power

    @ViewBuilder
    private var buyingPower: some View {
        if let ranges = s.dreamTierRanges {
            VStack(spacing: 8) {
                ForEach(DreamExtras.Tier.allCases, id: \.self) { t in
                    let on = s.dream.includedTiers.contains(t)
                    Button {
                        listings.changeSearch { $0.setTier(t, included: !on) }
                    } label: {
                        HStack(spacing: 12) {
                            CheckCircle(on: on)
                            Text(t.title).font(Nova.Typography.label14)
                            Spacer()
                            Text(Self.range(ranges[t]!)).font(Nova.Typography.label14)
                        }
                        .foregroundStyle(Nova.Color.text)
                        .padding(12)
                        .background(on ? Nova.Color.bgPrimary : Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Nova.Color.gray800 : Nova.Color.border, lineWidth: on ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(t.detail)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                Button("Clear my price range") { listings.changeSearch { $0.clearBuyingPower() } }
                    .buttonStyle(.novaLink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                NovaIcon("calculate", size: 24).foregroundStyle(Nova.Color.text)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Know what you can afford").font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                    Text("Won’t affect your credit score.").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                }
                Button(calculating ? "Calculating…" : "Calculate my buying power") {
                    calculating = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(1400))
                        let prices = listings.listings.map(\.price).sorted()
                        listings.changeSearch { $0.calculateBuyingPower(median: prices[prices.count / 2]) }
                        calculating = false
                        showToast("Buying power added")
                    }
                }
                .buttonStyle(.nova(.primary, size: .small))
                .disabled(calculating)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: Nova.Radius.widget))
        }
    }

    /// "$900K – $1M", "Up to $900K".
    static func range(_ r: ClosedRange<Int>) -> String {
        r.lowerBound == 0 ? "Up to \(SearchState.money(r.upperBound))" : "\(SearchState.money(r.lowerBound)) – \(SearchState.money(r.upperBound))"
    }

    // MARK: Buckets

    private func bucket(_ b: SearchState.DreamBucket, _ items: [DreamItem]) -> some View {
        let isEditing = editing.contains(b)
        return VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                ForEach(items) { item in pill(item, in: b, items: items, editing: isEditing) }
                if adding == b {
                    TextField(b == .must ? "e.g. 3+ beds" : b == .nice ? "e.g. Big backyard" : "e.g. HOA", text: $draft)
                        .font(Nova.Typography.label14)
                        .focused($addFocused)
                        .submitLabel(.done)
                        .onSubmit { commitAdd(b, keepOpen: true) }
                        .frame(width: 190, height: 38)
                        .padding(.horizontal, 12)
                        .background(Nova.Color.bgPrimary, in: Capsule())
                        .overlay(Capsule().strokeBorder(Nova.Color.gray800, lineWidth: 1.5))
                        .onChange(of: addFocused) { _, f in if !f { commitAdd(b, keepOpen: false) } }
                } else {
                    addPill("Add") { draft = ""; adding = b; addFocused = true }
                }
            }
            .modifier(Tray(highlighted: dropTarget == b))
            .dropDestination(for: String.self) { ids, _ in
                guard b != .deal, let id = ids.first, let item = (s.dreamMustHaves + s.dreamNiceToHaves).first(where: { $0.id == id }),
                      !items.contains(item) else { return false }
                move(item, to: b)
                return true
            } isTargeted: { on in
                if b != .deal { dropTarget = on ? b : (dropTarget == b ? nil : dropTarget) }
            }
            if b != .deal && !items.isEmpty {
                Button(isEditing ? "Done" : "Remove") {
                    if isEditing { editing.remove(b) } else { editing.insert(b) }
                }
                .buttonStyle(.novaLink)
            }
        }
    }

    private func pill(_ item: DreamItem, in b: SearchState.DreamBucket, items: [DreamItem], editing isEditing: Bool) -> some View {
        HStack(spacing: 4) {
            if b == .deal {
                NovaIcon("remove_circle", size: 14).foregroundStyle(Nova.Color.gray600).padding(.leading, 6)
            } else {
                NovaIcon("drag_handle", size: 16).foregroundStyle(Nova.Color.gray400).frame(width: 22, height: 32)
            }
            Text(item.label).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text).padding(.horizontal, 2)
            if b == .deal || isEditing || item.isFilter {
                circleButton("close", label: "Remove \(item.label)") { remove(item) }
            } else {
                circleButton(b == .must ? "arrow_downward" : "arrow_upward", label: b == .must ? "Make it a nice-to-have" : "Make it a must-have") {
                    move(item, to: b == .must ? .nice : .must)
                }
            }
        }
        .padding(.leading, 4).padding(.trailing, 3)
        .modifier(PillChrome())
        .draggable(item.id) {
            HStack(spacing: 4) {
                NovaIcon("drag_handle", size: 16)
                Text(item.label).font(Nova.Typography.label14)
            }
            .padding(.horizontal, 12).frame(height: 38)
            .background(Nova.Color.bgPrimary, in: Capsule())
            .rotationEffect(.degrees(-2))
        }
        .contextMenu {
            if !item.isFilter {
                if b != .must { Button("Make it a must-have") { move(item, to: .must) } }
                if b != .nice { Button("Make it a nice-to-have") { move(item, to: .nice) } }
                if b != .deal { Button("Make it a deal-breaker") { move(item, to: .deal) } }
            }
            Button("Remove", role: .destructive) { remove(item) }
        }
    }

    private func move(_ item: DreamItem, to b: SearchState.DreamBucket) {
        guard !item.isFilter else { return }
        withAnimation(Nova.Motion.easeOut()) { _ = listings.changeSearch { $0.moveDream(item, to: b) } }
        showToast("\(item.label) moved to " + (b == .must ? "must-haves" : b == .nice ? "nice-to-haves" : "deal-breakers"))
    }

    private func remove(_ item: DreamItem) {
        withAnimation(Nova.Motion.easeOut()) { _ = listings.changeSearch { $0.removeDream(item) } }
    }

    private func commitAdd(_ b: SearchState.DreamBucket, keepOpen: Bool) {
        var text = draft.trimmingCharacters(in: .whitespaces)
        if b == .deal { text = text.replacingRx(#"^(?i)(no|not|without)\s+"#, with: "") }
        draft = ""
        if !keepOpen { adding = nil }
        guard !text.isEmpty else { return }
        let before = s.dreamPreferenceCount
        withAnimation(Nova.Motion.easeOut()) { _ = listings.changeSearch { $0.addDream(text, to: b) } }
        if s.dreamPreferenceCount == before && !text.rx(#"^\d"#) {
            showToast("Already in your " + (b == .must ? "must-haves" : b == .nice ? "nice-to-haves" : "deal-breakers"))
        }
        if keepOpen { addFocused = true }
    }

    // MARK: Inspiration

    @ViewBuilder
    private var inspiration: some View {
        let photos = s.dream.inspiration
        VStack(alignment: .leading, spacing: 12) {
            if photos.isEmpty {
                HStack(spacing: 8) {
                    NovaIcon("favorite", size: 18)
                    Text("Tap ♥ on listing photos to add them here.").font(Nova.Typography.body14)
                }
                .foregroundStyle(Nova.Color.textSubtle)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack {
                            ForEach(Array(photos.suffix(3).enumerated()), id: \.offset) { i, name in
                                let n = min(photos.count, 3), depth = n - 1 - i
                                ListingPhoto(url: HomePhotos.url(name))
                                    .frame(width: 104, height: 104)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                                    .rotationEffect(.degrees(depth == 2 ? -7 : depth == 1 ? 5 : 0))
                                    .brightness(depth > 0 ? -0.08 : 0)
                            }
                        }
                        .frame(width: 112, height: 112)
                        Text("Exteriors").font(.nova(13, .medium)).foregroundStyle(Nova.Color.text)
                        Text(photos.count == 1 ? "1 photo" : "\(photos.count) photos").font(Nova.Typography.caption12).foregroundStyle(Nova.Color.gray500)
                    }
                    Spacer()
                }
            }
            Button { showInspiration = true } label: {
                Label { Text("Find inspiration") } icon: { NovaIcon("image_search", size: 18) }
            }
            .buttonStyle(.nova(.secondary, size: .small))
        }
    }

    // MARK: Suggestions

    @ViewBuilder
    private var suggestions: some View {
        let saved = listings.listings.filter { listings.savedListingIDs.contains($0.id) }
        let recs = s.dreamRecommendations(saved: saved)
        if let first = recs.first {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(first.criterion.capitalizedFirst).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text)
                        Text(first.evidence).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                    }
                    Spacer(minLength: 0)
                    circleButton("close", label: "Not for me", size: 32) {
                        listings.changeSearch { $0.dream.dismissed.append(first.criterion) }
                    }
                    Button("+ Nice-to-have") {
                        listings.changeSearch { $0.addDream(first.criterion, to: .nice) }
                        showToast("\(first.criterion.capitalizedFirst) added to nice-to-haves")
                    }
                    .buttonStyle(.nova(.primary, size: .xSmall))
                }
                .padding(12)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Nova.Color.border, lineWidth: 1))
                if recs.count > 1 { sortCard(Array(recs.dropFirst())) }
            }
        } else {
            Text("Nothing yet. Suggestions appear as you browse.")
                .font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
        }
    }

    private func sortCard(_ rest: [DreamRecommendation]) -> some View {
        Button { sorterItems = rest } label: {
            HStack(spacing: 14) {
                MiniDeck()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sort \(rest.count) more suggestion\(rest.count == 1 ? "" : "s")").font(Nova.Typography.label16)
                    Text("Swipe each into must-have, nice-to-have or deal-breaker").font(.nova(13)).foregroundStyle(Nova.Color.textSubtle)
                }
                .foregroundStyle(Nova.Color.text)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                NovaIcon("arrow_forward", size: 20).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(Color(white: 0.067), in: Circle())
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 14))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Nova.Color.borderEmphasis, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: Find homes, toast

    private var findButton: some View {
        Button { session.findDreamMatches() } label: {
            ZStack(alignment: .bottomTrailing) {
                NovaIcon("house", size: 26)
                NovaIcon("search", size: 14).padding(2).background(Color(white: 0.067), in: Circle()).offset(x: 6, y: 4)
            }
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .background(Color(white: 0.067), in: Circle())
        .novaElevation(.level3)
        .padding(16)
        .accessibilityLabel("Find homes that match")
        .disabled(session.isBusy)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.nova(13)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(white: 0.067), in: RoundedRectangle(cornerRadius: 12))
                .novaElevation(.level3)
                .padding(.bottom, 88)
                .transition(.opacity.combined(with: .offset(y: 8)))
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(Nova.Motion.easeOut()) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .milliseconds(2400))
            guard !Task.isCancelled else { return }
            withAnimation(Nova.Motion.easeOut()) { toast = nil }
        }
    }

    // MARK: Helpers

    private func dreamBinding<V>(_ kp: WritableKeyPath<DreamExtras, V>) -> Binding<V> {
        Binding(get: { listings.search.dream[keyPath: kp] }, set: { v in listings.search.dream[keyPath: kp] = v })
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.nova(22, .medium)).tracking(-0.4).foregroundStyle(Nova.Color.text)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func circleButton(_ icon: String, label: String, size: CGFloat = 30, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NovaIcon(icon, size: 16).foregroundStyle(Nova.Color.text)
                .frame(width: size, height: size).background(Nova.Color.bgSecondary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func addPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { Text(title) } icon: { NovaIcon("add", size: 16) }
                .font(.nova(13, .medium)).foregroundStyle(Nova.Color.gray700)
                .padding(.horizontal, 12).frame(height: 38)
                .overlay(Capsule().strokeBorder(Nova.Color.gray300, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pieces

private struct SorterDeck: Identifiable {
    let items: [DreamRecommendation]
    var id: String { items.map(\.id).joined() }
}

/// 38pt white pill with a hairline.
private struct PillChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.frame(height: 38)
            .background(Nova.Color.bgPrimary, in: Capsule())
            .overlay(Capsule().strokeBorder(Nova.Color.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

/// Gray tray holding pills; rings while a drag hovers it.
private struct Tray: ViewModifier {
    var highlighted = false
    func body(content: Content) -> some View {
        content.padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                if highlighted {
                    RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Nova.Color.gray800, lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            .animation(Nova.Motion.easeOut(), value: highlighted)
    }
}

struct CheckCircle: View {
    let on: Bool
    var body: some View {
        Group {
            if on {
                NovaIcon("check", size: 14).foregroundStyle(.white).frame(width: 22, height: 22).background(Color(white: 0.067), in: Circle())
            } else {
                Circle().strokeBorder(Nova.Color.gray300, lineWidth: 1.5).frame(width: 22, height: 22)
            }
        }
    }
}

/// Four fanned mini cards in the sorter's zone colors.
private struct MiniDeck: View {
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 7)
                    .fill([Color(red: 94 / 255, green: 121 / 255, blue: 217 / 255), Color(white: 0.067), Nova.Color.brandFixed, .white][i])
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(i == 3 ? Nova.Color.gray800 : .clear, lineWidth: 1.5))
                    .frame(width: 30, height: 38)
                    .rotationEffect(.degrees(Double(i - 2) * 6 + 3), anchor: .bottom)
            }
        }
        .frame(width: 46, height: 44)
        .accessibilityHidden(true)
    }
}

/// Pick bundled exterior photos you like for "It looks like".
private struct InspirationPicker: View {
    @Bindable var session: AskSession
    let onAdded: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var picked: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick photos that feel like home. We’ll rank similar homes higher.")
                        .font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(HomeCatalog.exteriorPhotos, id: \.self) { name in tile(name) }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Find inspiration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) { dismiss() } label: { NovaIcon("close", size: 20) }
                    } else {
                        Button { dismiss() } label: { NovaIcon("close", size: 20) }.accessibilityLabel("Close")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text(picked.isEmpty ? "Tap photos you like" : "\(picked.count) selected").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                    Spacer()
                    Button(picked.count <= 1 ? (picked.isEmpty ? "Add photos" : "Add 1 photo") : "Add \(picked.count) photos") {
                        session.listings.search.dream.inspiration += picked
                        onAdded(picked.count)
                        dismiss()
                    }
                    .buttonStyle(.nova(.primary))
                    .disabled(picked.isEmpty)
                }
                .padding(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 16))
                .background(.bar)
            }
        }
        .presentationDetents([.fraction(0.88), .large])
    }

    private func tile(_ name: String) -> some View {
        let saved = session.listings.search.dream.inspiration.contains(name), on = picked.contains(name)
        return Button {
            if let i = picked.firstIndex(of: name) { picked.remove(at: i) } else { picked.append(name) }
        } label: {
            ListingPhoto(url: HomePhotos.url(name))
                .aspectRatio(4 / 5, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay { if on { RoundedRectangle(cornerRadius: 16).strokeBorder(Color(white: 0.067), lineWidth: 3) } }
                .overlay(alignment: .topTrailing) {
                    Group {
                        if on { NovaIcon("check", size: 16).foregroundStyle(.white).frame(width: 28, height: 28).background(Color(white: 0.067), in: Circle()) }
                        else if !saved { NovaIcon("favorite", size: 16).foregroundStyle(Nova.Color.text).frame(width: 28, height: 28).background(Nova.Color.bgPrimary, in: Circle()).novaElevation(.level1) }
                    }
                    .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    if saved {
                        Text("Already saved").font(Nova.Typography.label12).foregroundStyle(Nova.Color.text)
                            .padding(.horizontal, 8).frame(height: 24).background(.white, in: Capsule()).padding(8)
                    }
                }
                .opacity(saved ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(saved)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private extension View {
    /// Sections rise in on first appearance (`dhRise`).
    func rise(_ on: Bool, _ delay: Double) -> some View {
        opacity(on ? 1 : 0).offset(y: on ? 0 : 14)
            .animation(.easeOut(duration: 0.55).delay(delay), value: on)
    }
}
