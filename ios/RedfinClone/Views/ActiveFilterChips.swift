import SwiftUI

struct ActiveFilterChips: View {
    @Bindable var viewModel: ListingsViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(chips) { chip in
                    chipView(chip)
                }
                if viewModel.hasActiveFilters {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            viewModel.clearAllFilters()
                        }
                    } label: {
                        Text("Clear all")
                            .font(.inter(13, .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .frame(height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .scrollClipDisabled()
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: chips.map { $0.id })
    }

    private func chipView(_ chip: FilterChip) -> some View {
        HStack(spacing: 6) {
            Text(chip.label)
                .font(.inter(13, .semibold))
                .foregroundStyle(.primary)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    chip.clear()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, Theme.Spacing.sm)
        .padding(.trailing, 4)
        .frame(height: 32)
        .background {
            if #available(iOS 26.0, *) {
                Capsule().fill(.clear).glassEffect(in: .capsule)
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var chips: [FilterChip] {
        var result: [FilterChip] = []

        for n in viewModel.filterNeighborhoods {
            result.append(FilterChip(id: "n-\(n)", label: n) {
                viewModel.filterNeighborhoods.removeAll { $0 == n }
            })
        }

        if viewModel.filterMinBeds > 0 {
            let beds = viewModel.filterMinBeds
            result.append(FilterChip(id: "beds", label: beds == 0 ? "Studio" : "\(beds)+ bd") {
                viewModel.filterMinBeds = 0
            })
        }

        if viewModel.filterMinBaths > 0 {
            let baths = viewModel.filterMinBaths
            result.append(FilterChip(id: "baths", label: "\(baths)+ ba") {
                viewModel.filterMinBaths = 0
            })
        }

        if viewModel.filterMinPrice != nil || viewModel.filterMaxPrice != nil {
            let label = priceRangeLabel(min: viewModel.filterMinPrice, max: viewModel.filterMaxPrice)
            result.append(FilterChip(id: "price", label: label) {
                viewModel.filterMinPrice = nil
                viewModel.filterMaxPrice = nil
            })
        }

        if let type = viewModel.filterPropertyType {
            result.append(FilterChip(id: "type", label: type) {
                viewModel.filterPropertyType = nil
            })
        }

        if viewModel.filterIsHotHome {
            result.append(FilterChip(id: "hot", label: "Hot homes") {
                viewModel.filterIsHotHome = false
            })
        }

        return result
    }

    private func priceRangeLabel(min: Int?, max: Int?) -> String {
        func fmt(_ v: Int) -> String {
            if v >= 1_000_000 {
                let m = Double(v) / 1_000_000.0
                return m == m.rounded() ? "$\(Int(m))M" : String(format: "$%.1fM", m)
            }
            return "$\(v / 1000)K"
        }
        switch (min, max) {
        case (let a?, let b?): return "\(fmt(a))–\(fmt(b))"
        case (let a?, nil): return "\(fmt(a))+"
        case (nil, let b?): return "Up to \(fmt(b))"
        default: return "Price"
        }
    }
}

private struct FilterChip: Identifiable {
    let id: String
    let label: String
    let clear: () -> Void
}
