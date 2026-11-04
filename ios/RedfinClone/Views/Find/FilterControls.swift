import SwiftUI

// Filter controls shared by the Filters sheet and the Price / Beds & baths popovers.

/// Histogram of listing prices ($200K–$1.5M in $50K bins) over a dual-thumb
/// slider with $25K steps, plus read-only Minimum / Maximum boxes.
struct PriceRangeControl: View {
    @Binding var minPrice: Int
    @Binding var maxPrice: Int
    let listings: [Listing]

    static let low = 200_000, high = 1_500_000, step = 25_000

    private var bars: [(from: Int, to: Int, count: Int, height: Int)] { SearchEngine.priceHistogram(listings) }
    private var lowerValue: Int { minPrice > 0 ? minPrice : Self.low }
    private var upperValue: Int { maxPrice > 0 ? maxPrice : Self.high }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(bars, id: \.from) { bar in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(bar.to > lowerValue && bar.from < upperValue ? Nova.Color.gray800 : Nova.Color.gray300)
                            .frame(height: 72 * CGFloat(bar.height) / 100)
                    }
                }
                .frame(height: 72, alignment: .bottom)
                .accessibilityHidden(true)
                RangeSlider(lower: lowerBinding, upper: upperBinding, bounds: Self.low...Self.high, step: Self.step)
            }
            HStack(spacing: 12) {
                valueBox("Minimum", minPrice > 0 ? SearchState.money(minPrice) : "No min")
                Rectangle().fill(Nova.Color.borderEmphasis).frame(width: 8, height: 1)
                valueBox("Maximum", maxPrice > 0 ? SearchState.money(maxPrice) : "No max")
            }
        }
    }

    // Thumbs at the ends mean "no min" / "no max".
    private var lowerBinding: Binding<Int> {
        Binding(get: { lowerValue }, set: { minPrice = $0 <= Self.low ? 0 : $0 })
    }
    private var upperBinding: Binding<Int> {
        Binding(get: { upperValue }, set: { maxPrice = $0 >= Self.high ? 0 : $0 })
    }

    private func valueBox(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Nova.Typography.caption12).foregroundStyle(Nova.Color.textSubtle)
            Text(value).font(Nova.Typography.body16).foregroundStyle(Nova.Color.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nova.Color.bgSecondary, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
        .accessibilityElement(children: .combine)
    }
}

/// Two-thumb slider: 24pt white thumbs with a gray ring, gray-800 active track.
struct RangeSlider: View {
    @Binding var lower: Int
    @Binding var upper: Int
    let bounds: ClosedRange<Int>
    let step: Int

    @State private var dragStart: (lower: Int, upper: Int)?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width - 24
            let x = { (v: Int) in CGFloat(v - bounds.lowerBound) / CGFloat(bounds.upperBound - bounds.lowerBound) * width + 12 }
            ZStack(alignment: .leading) {
                Capsule().fill(Nova.Color.gray300).frame(height: 4).padding(.horizontal, 12)
                Capsule().fill(Nova.Color.gray800)
                    .frame(width: max(x(upper) - x(lower), 0), height: 4)
                    .offset(x: x(lower))
                thumb.position(x: x(lower), y: 22).gesture(drag(width: width, isLower: true))
                    .accessibilityLabel("Minimum price")
                    .accessibilityValue(SearchState.money(lower))
                    .accessibilityAdjustableAction { adjust(isLower: true, $0) }
                thumb.position(x: x(upper), y: 22).gesture(drag(width: width, isLower: false))
                    .accessibilityLabel("Maximum price")
                    .accessibilityValue(SearchState.money(upper))
                    .accessibilityAdjustableAction { adjust(isLower: false, $0) }
            }
        }
        .frame(height: 44)
        .sensoryFeedback(.selection, trigger: lower)
        .sensoryFeedback(.selection, trigger: upper)
    }

    private var thumb: some View {
        Circle()
            .fill(.white)
            .frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(Nova.Color.gray300, lineWidth: 1))
            .novaElevation(.level2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private func drag(width: CGFloat, isLower: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let start = dragStart ?? (lower, upper)
                if dragStart == nil { dragStart = start }
                let span = CGFloat(bounds.upperBound - bounds.lowerBound)
                let delta = Int((g.translation.width / width * span / CGFloat(step)).rounded()) * step
                if isLower {
                    lower = min(max(start.lower + delta, bounds.lowerBound), upper - step)
                } else {
                    upper = max(min(start.upper + delta, bounds.upperBound), lower + step)
                }
            }
            .onEnded { _ in dragStart = nil }
    }

    private func adjust(isLower: Bool, _ direction: AccessibilityAdjustmentDirection) {
        let d = direction == .increment ? step : -step
        if isLower { lower = min(max(lower + d, bounds.lowerBound), upper - step) }
        else { upper = max(min(upper + d, bounds.upperBound), lower + step) }
    }
}

/// Wrapping row of single-select chips ("Any", "1+", ...).
struct ChipChoiceRow<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.0) { value, title in
                NovaChip(title: title, isSelected: selection == value, style: .outline) {
                    selection = value
                }
            }
        }
    }
}

/// Wrapping row of multi-select chips (home types, features).
struct ChipToggleRow: View {
    let options: [String]
    @Binding var selection: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                NovaChip(title: option, isSelected: selection.contains(option), style: .outline) {
                    if let i = selection.firstIndex(of: option) { selection.remove(at: i) } else { selection.append(option) }
                }
            }
        }
    }
}

/// Beds and Baths chip groups.
struct RoomsControl: View {
    @Binding var beds: Int
    @Binding var baths: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FilterGroup("Beds") {
                ChipChoiceRow(options: [(0, "Any"), (1, "1+"), (2, "2+"), (3, "3+"), (4, "4+")], selection: $beds)
            }
            FilterGroup("Baths") {
                ChipChoiceRow(options: [(0.0, "Any"), (1.0, "1+"), (1.5, "1.5+"), (2.0, "2+"), (3.0, "3+")], selection: $baths)
            }
        }
    }
}

/// Section title over its controls.
struct FilterGroup<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Nova.Typography.label16).foregroundStyle(Nova.Color.text)
                if let subtitle {
                    Text(subtitle).font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Left-aligned wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var y: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
