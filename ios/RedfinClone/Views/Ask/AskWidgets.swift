import SwiftUI

/// Everything that can sit under a reply once it has finished typing: home
/// cards, the widget and the CTA button.
struct AskAttachments: View {
    @Bindable var session: AskSession
    let entry: AskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !entry.homes.isEmpty {
                AskHomeCards(session: session, ids: entry.homes, total: entry.homesTotal)
            }
            if let widget = entry.widget {
                widgetView(widget)
            }
            if let cta = entry.cta {
                Button(cta.label) { session.tapCTA(cta) }
                    .buttonStyle(.nova(.primary, size: .small))
                    .disabled(session.isBusy)
            }
        }
        .transition(.opacity.combined(with: .offset(y: 8)))
    }

    @ViewBuilder
    private func widgetView(_ w: AskWidget) -> some View {
        switch w {
        case .homes(let ids, let total): AskHomeCards(session: session, ids: ids, total: total)
        case .compare(let ids): AskCompareTable(session: session, ids: ids)
        case .pick(let p): AskTourPicker(session: session, entryID: entry.id, pick: p)
        case .itinerary(let plan): AskItinerary(session: session, entryID: entry.id, plan: plan, state: entry.widgetState)
        case .debrief(let ids): AskDebrief(session: session, entryID: entry.id, ids: ids, reactions: entry.widgetState.reactions)
        case .watch(let ws): VStack(spacing: 8) { ForEach(ws) { AskWatchCard(session: session, watch: $0) } }
        case .inspiration: AskInspiration(session: session, entryID: entry.id, picked: entry.widgetState.picked)
        case .addPhoto:
            Button { session.photoPickerRequested = true } label: {
                Label { Text("Add a photo") } icon: { NovaIcon("add_photo_alternate", size: 20) }
            }
            .buttonStyle(.nova(.secondary, size: .small))
        case .confirmMinSqft(let v, let yes, let no):
            HStack(spacing: 8) {
                Button(yes) { session.confirmMinSqft(entry.id, value: v, accept: true) }.buttonStyle(.nova(.primary, size: .small))
                Button(no) { session.confirmMinSqft(entry.id, value: v, accept: false) }.buttonStyle(.nova(.secondary, size: .small))
            }
            .disabled(entry.widgetState.used || session.isBusy)
        }
    }
}

// MARK: - Shared bits

/// Small rounded listing photo.
private struct Thumb: View {
    let listing: Listing?
    var size: CGFloat = 44
    var body: some View {
        ListingPhoto(url: listing?.photos.first)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// White, radius 16, hairline ring.
private struct WidgetCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Nova.Color.bgPrimary, in: RoundedRectangle(cornerRadius: Nova.Radius.widget, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Nova.Radius.widget, style: .continuous).strokeBorder(Nova.Color.border, lineWidth: 1))
    }
}

extension AskSession {
    func listing(_ id: String) -> Listing? { listings.listings.first { $0.id == id } }
}

// MARK: - Home cards

struct AskHomeCards: View {
    @Bindable var session: AskSession
    let ids: [String]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(ids.compactMap(session.listing)) { l in
                        AskHomeCard(listing: l, isSaved: session.listings.isSaved(l),
                                    onTap: { session.openHome(l.id) },
                                    onToggleSave: { session.listings.toggleSaved(l) })
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            Button { session.showOnMap(ids) } label: {
                Label { Text("Show \(AskText.homes(max(total, ids.count))) on map") } icon: { NovaIcon("map", size: 20) }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.nova(.secondary, size: .small, fullWidth: true))
        }
    }
}

private struct AskHomeCard: View {
    let listing: Listing
    let isSaved: Bool
    let onTap: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ListingPhoto(url: listing.photos.first)
                .frame(width: 280, height: 170)
                .overlay(alignment: .topLeading) {
                    if listing.isHotHome { NovaTag(title: "Hot home", variant: .rocket, size: .small).padding(10) }
                }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(listing.formattedFullPrice).font(.nova(18, .demibold)).foregroundStyle(Nova.Color.text)
                    Spacer()
                    ShareLink(item: listing.shareText) {
                        NovaIcon("ios_share", size: 22).foregroundStyle(Nova.Color.text).frame(width: 40, height: 40)
                    }
                    .accessibilityLabel("Share")
                    SaveHeartButton(isSaved: isSaved, action: onToggleSave)
                }
                HomeFactsLine(listing: listing)
                Text(listing.fullAddress).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 280)
        .background(Nova.Color.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(white: 0.82), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Show on map", onTap)
    }
}

// MARK: - Compare

struct AskCompareTable: View {
    @Bindable var session: AskSession
    let ids: [String]

    private struct Row { let label: String; let values: [String]; let best: Set<Int> }
    private let rowHeight: CGFloat = 44, headerHeight: CGFloat = 112, colWidth: CGFloat = 148, labelWidth: CGFloat = 104

    private var homes: [Listing] { ids.compactMap(session.listing) }

    private var rows: [Row] {
        let xs = homes
        func best(_ v: [Double?], high: Bool) -> Set<Int> {
            let vals = v.compactMap { $0 }
            guard let target = high ? vals.max() : vals.min(), vals.count > 1, Set(vals).count > 1 else { return [] }
            return Set(v.indices.filter { v[$0] == target })
        }
        let ppsf = xs.map { $0.sqft > 0 ? Double($0.price) / Double($0.sqft) : nil }
        let condRank = ["Excellent": 4.0, "Good": 3, "Fair": 2, "Needs work": 1]
        var out = [
            Row(label: "Price", values: xs.map(\.formattedPrice), best: best(xs.map { Double($0.price) }, high: false)),
            Row(label: "Price per sq ft", values: ppsf.map { $0.map { "$\(Int($0.rounded()))" } ?? "—" }, best: best(ppsf, high: false)),
            Row(label: "Beds", values: xs.map { "\($0.beds)" }, best: best(xs.map { Double($0.beds) }, high: true)),
            Row(label: "Baths", values: xs.map(\.bathsFormatted), best: best(xs.map(\.baths), high: true)),
            Row(label: "Sq ft", values: xs.map { $0.sqft > 0 ? $0.sqft.formatted() : "—" }, best: best(xs.map { $0.sqft > 0 ? Double($0.sqft) : nil }, high: true)),
            Row(label: "Year built", values: xs.map { "\($0.yearBuilt)" }, best: best(xs.map { Double($0.yearBuilt) }, high: true)),
            Row(label: "HOA", values: xs.map { HomeCatalog.hoa($0) > 0 ? "$\(HomeCatalog.hoa($0))/mo" : "None" }, best: best(xs.map { Double(HomeCatalog.hoa($0)) }, high: false)),
            Row(label: "Days on Redfin", values: xs.map { "\($0.daysOnMarket)" }, best: best(xs.map { Double($0.daysOnMarket) }, high: false)),
            Row(label: "Transit score", values: xs.map { $0.facts?.transitScore.map(String.init) ?? "—" }, best: best(xs.map { $0.facts?.transitScore.map(Double.init) }, high: true)),
            Row(label: "Condition", values: xs.map { $0.facts?.condition ?? "—" }, best: best(xs.map { condRank[$0.facts?.condition ?? ""] }, high: true)),
        ]
        for c in session.listings.search.scoringCriteria {
            let has = xs.map { HomeCatalog.has($0, c) }
            out.append(Row(label: c.capitalizedFirst, values: has.map { $0 ? "Yes" : "Not mentioned" },
                           best: has.contains(false) ? Set(has.indices.filter { has[$0] }) : []))
        }
        return out
    }

    var body: some View {
        let rows = rows
        WidgetCard(padding: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(width: labelWidth + 12, height: headerHeight)
                    ForEach(rows.indices, id: \.self) { i in
                        Text(rows[i].label)
                            .font(Nova.Typography.label12)
                            .foregroundStyle(Nova.Color.textSubtle)
                            .lineLimit(2)
                            .frame(width: labelWidth, height: rowHeight, alignment: .leading)
                            .padding(.leading, 12)
                    }
                }
                .background(Nova.Color.bgPrimary)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(homes.enumerated()), id: \.element.id) { j, x in
                            VStack(spacing: 0) {
                                Button { session.openHome(x.id) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Thumb(listing: x, size: 72)
                                        Text(x.address).font(Nova.Typography.label12).foregroundStyle(Nova.Color.text).lineLimit(2)
                                    }
                                    .frame(width: colWidth - 16, height: headerHeight - 8, alignment: .topLeading)
                                }
                                .buttonStyle(.plain)
                                ForEach(rows.indices, id: \.self) { i in
                                    let isBest = rows[i].best.contains(j)
                                    Text(rows[i].values[j])
                                        .font(isBest ? .nova(14, .demibold) : Nova.Typography.body14)
                                        .foregroundStyle(isBest ? Nova.Color.green800 : Nova.Color.text)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.horizontal, 8)
                                        .frame(width: colWidth - 8, height: rowHeight - 6, alignment: .leading)
                                        .background(isBest ? Nova.Color.green50 : .clear, in: RoundedRectangle(cornerRadius: 8))
                                        .frame(height: rowHeight)
                                }
                            }
                            .frame(width: colWidth)
                            .padding(.top, 8)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Comparison of \(homes.count) homes")
    }
}

// MARK: - Watch

struct AskWatchCard: View {
    @Bindable var session: AskSession
    let watch: HomeWatch

    var body: some View {
        let status = session.watchStatus(watch), x = session.listing(watch.listingID)
        WidgetCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Thumb(listing: x, size: 48)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(x?.address ?? "").font(Nova.Typography.label14).foregroundStyle(Nova.Color.text).lineLimit(1)
                        Text(x?.formattedPrice ?? "").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                    }
                    Spacer(minLength: 4)
                    statusTag(status)
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                    GridRow {
                        Text("When").font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                        Text("Then").font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                    }
                    GridRow(alignment: .top) {
                        Text(watch.label).font(Nova.Typography.body14)
                        Text(watch.action == .tour ? "Request a tour for the next open slot, then tell me here" : "Tell me here").font(Nova.Typography.body14)
                    }
                }
                .foregroundStyle(Nova.Color.text)
                HStack(spacing: 8) {
                    Button { session.simulateTrigger(watch) } label: {
                        Label { Text("Simulate a trigger") } icon: { NovaIcon("notifications_active", size: 18) }
                    }
                    .buttonStyle(.nova(.secondary, size: .small))
                    Button("Stop watching") { session.stopWatching(watch) }
                        .buttonStyle(.nova(.tertiary, size: .small))
                }
                .disabled(status != .on || session.isBusy)
            }
        }
        .opacity(status == .off ? 0.6 : 1)
    }

    private func statusTag(_ s: HomeWatch.Status) -> some View {
        let (text, bg, fg): (String, Color, Color) = switch s {
        case .on: ("Watching", Nova.Color.green50, Nova.Color.green800)
        case .hit: ("Triggered", Color(white: 0.067), .white)
        case .off: ("Stopped", Nova.Color.gray100, Nova.Color.gray600)
        }
        return HStack(spacing: 6) {
            Circle().fill(fg).frame(width: 6, height: 6)
            Text(text).font(Nova.Typography.label12)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(bg, in: Capsule())
    }
}

// MARK: - Tour-day picker

struct AskTourPicker: View {
    @Bindable var session: AskSession
    let entryID: UUID
    let pick: TourPick

    var body: some View {
        let n = pick.selected.count
        WidgetCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(n) of \(pick.candidates.count) selected").font(Nova.Typography.label14).foregroundStyle(Nova.Color.text)
                    Spacer()
                    Picker("Day", selection: Binding(get: { pick.day }, set: { session.setPickDay(entryID, $0) })) {
                        Text("Saturday").tag("Sat")
                        Text("Sunday").tag("Sun")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .disabled(pick.done)
                }
                ForEach(pick.candidates, id: \.self) { id in
                    if let x = session.listing(id) { row(x, on: pick.selected.contains(id)) }
                }
                Button { session.planPicked(entryID) } label: {
                    Label {
                        Text(pick.done ? "Planned" : n < 2 ? "Pick at least 2 homes" : "Plan my \(AskRouter.dayName(pick.day)) (\(n) stops)")
                    } icon: { NovaIcon("route", size: 18) }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.nova(.primary, size: .regular, fullWidth: true))
                .disabled(pick.done || n < 2 || session.isBusy)
                .padding(.top, 4)
            }
        }
    }

    private func row(_ x: Listing, on: Bool) -> some View {
        Button { session.togglePick(entryID, x.id) } label: {
            HStack(spacing: 10) {
                Group {
                    if on { NovaIcon("check_circle", size: 24).foregroundStyle(Nova.Color.text) }
                    else { Circle().strokeBorder(Nova.Color.gray600, lineWidth: 1.5).frame(width: 22, height: 22).padding(1) }
                }
                Thumb(listing: x)
                VStack(alignment: .leading, spacing: 0) {
                    Text(x.address).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text).lineLimit(1)
                    Text([x.formattedPrice, "\(x.beds) bd", "\(x.bathsFormatted) ba", x.facts?.openHouse.map { "Open house " + Self.openTime($0) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pick.done)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// "October-24-2026 11:00 AM" → "11:00 AM"
    static func openTime(_ s: String) -> String { s.split(separator: " ").dropFirst().joined(separator: " ") }
}

// MARK: - Itinerary

struct AskItinerary: View {
    @Bindable var session: AskSession
    let entryID: UUID
    let plan: TourPlan
    let state: AskWidgetState

    var body: some View {
        let current = session.isCurrentItinerary(entryID)
        WidgetCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(AskRouter.dayName(plan.day)).font(.nova(18, .demibold)).foregroundStyle(Nova.Color.text)
                    Spacer()
                    Text("\(plan.stops.count) stops · \(plan.driveTotal) min driving").font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                }
                ForEach(Array(plan.stops.enumerated()), id: \.element.listingID) { i, stop in
                    if i > 0 {
                        HStack(spacing: 8) {
                            Rectangle().fill(Nova.Color.border).frame(width: 2, height: 22).padding(.leading, 11)
                            NovaIcon("car", size: 16)
                            Text("\(stop.drive) min drive").font(Nova.Typography.caption12)
                        }
                        .foregroundStyle(Nova.Color.textSubtle)
                    }
                    if let x = session.listing(stop.listingID) {
                        HStack(spacing: 10) {
                            Text("\(i + 1)")
                                .font(.novaFixed(12, .demibold)).foregroundStyle(.white)
                                .frame(width: 24, height: 24).background(Nova.Color.brandFixed, in: Circle())
                            Thumb(listing: x)
                            VStack(alignment: .leading, spacing: 0) {
                                Button(x.address) { session.openHome(x.id) }
                                    .buttonStyle(.plain).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text).underline().lineLimit(1)
                                Text([AskRouter.clock(stop.at), x.formattedPrice, x.facts?.openHouse.map { "Open house " + AskTourPicker.openTime($0) }].compactMap { $0 }.joined(separator: " · "))
                                    .font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            if current && plan.stops.count > 2 {
                                Button { session.removeStop(entryID, stop.listingID) } label: { NovaIcon("close", size: 16).frame(width: 32, height: 32) }
                                    .buttonStyle(.plain).foregroundStyle(Nova.Color.textSubtle)
                                    .accessibilityLabel("Remove \(x.address)")
                            }
                        }
                    }
                }
                FlowRow {
                    Button { session.toggleRoute(entryID) } label: {
                        Label { Text(state.onMap ? "Hide route" : "Show route on map") } icon: { NovaIcon("map", size: 18) }
                    }
                    .buttonStyle(.nova(.primary, size: .small))
                    Button { session.requestTours(entryID) } label: {
                        Label { Text(plan.requested ? "Tours requested" : "Request tours") } icon: { NovaIcon("calendar_clock", size: 18) }
                    }
                    .buttonStyle(.nova(.secondary, size: .small))
                    .disabled(plan.requested || !current)
                    Button("After touring") { session.send("I’m back from touring") }
                        .buttonStyle(.nova(.secondary, size: .small))
                }
                .disabled(session.isBusy)
                .padding(.top, 4)
            }
        }
    }
}

/// Wraps buttons onto new lines when they don't fit.
private struct FlowRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { content() }
            VStack(alignment: .leading, spacing: 8) { content() }
        }
    }
}

// MARK: - Debrief

struct AskDebrief: View {
    @Bindable var session: AskSession
    let entryID: UUID
    let ids: [String]
    let reactions: [String: String]

    static let options = [("loved", "Loved it"), ("small", "Felt small"), ("dark", "Too dark"), ("noisy", "Noisy street"), ("no", "Not for me")]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(ids, id: \.self) { id in
                if let x = session.listing(id) {
                    WidgetCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Thumb(listing: x)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(x.address).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text).lineLimit(1)
                                    Text("\(x.formattedPrice) · \(x.sqft > 0 ? x.sqft.formatted() : "—") sq ft").font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
                                }
                            }
                            ScrollView(.horizontal) {
                                HStack(spacing: 6) {
                                    ForEach(Self.options, id: \.0) { k, label in
                                        let picked = reactions[id]
                                        NovaChip(title: label, isSelected: picked == k, style: .outline) { session.react(entryID, id, k) }
                                            .opacity(picked == nil || picked == k ? 1 : 0.5)
                                            .disabled(picked != nil || session.isBusy)
                                    }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Inspiration

struct AskInspiration: View {
    @Bindable var session: AskSession
    let entryID: UUID
    let picked: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(AskSession.inspiration, id: \.key) { tile in
                Button { session.pickStyle(entryID, tile.key) } label: {
                    ListingPhoto(url: HomePhotos.url(tile.photo))
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text(tile.label)
                                .font(Nova.Typography.label12).foregroundStyle(Nova.Color.text)
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Nova.Color.bgPrimary, in: Capsule())
                                .novaElevation(.level1)
                                .padding(8)
                        }
                        .overlay {
                            if picked == tile.key {
                                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color(white: 0.067), lineWidth: 3)
                            }
                        }
                        .opacity(picked == nil || picked == tile.key ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(picked != nil || session.isBusy)
                .accessibilityLabel(tile.label)
            }
        }
    }
}
