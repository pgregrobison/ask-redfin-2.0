import SwiftUI

struct NewChatEmptyStateView: View {
    let lastFilters: SearchFilters?
    let onSuggestionTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            heading
            cards
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xxl)
    }

    // MARK: - Heading

    private var heading: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs + 2) {
                Image(systemName: "sparkle")
                    .font(.system(size: 26, weight: .semibold))
                Text("Ask Redfin")
                    .font(.nova(32, .demibold))
                Spacer(minLength: 0)
            }
            Text("What can I help you find?")
                .font(.nova(20))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Cards

    private var cards: some View {
        VStack(spacing: Theme.Spacing.sm) {
            resumeCard

            HStack(spacing: Theme.Spacing.sm) {
                smallCard(
                    icon: "sparkles",
                    title: "What's new\nthis week?",
                    prompt: "Show me new listings from the last 7 days"
                )
                smallCard(
                    icon: "arrow.left.arrow.right",
                    title: "Compare\nneighborhoods",
                    prompt: "Compare two neighborhoods for me"
                )
            }

            wideCard(
                icon: "slider.horizontal.3",
                title: "Help me narrow it down",
                subtitle: "Tell me what matters most and I'll find homes that fit",
                prompt: "Help me figure out what I'm looking for in a home"
            )
        }
    }

    // MARK: - Resume card

    @ViewBuilder
    private var resumeCard: some View {
        let chipLabels = lastFilters.map { filterChipLabels(for: $0) } ?? []
        let hasFilters = !chipLabels.isEmpty

        EmptyStateCard {
            onSuggestionTap(hasFilters ? buildResumePrompt(from: lastFilters!) : "Show me homes for sale in Seattle")
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label(
                        hasFilters ? "Pick up where you left off" : "Start searching",
                        systemImage: hasFilters ? "arrow.counterclockwise" : "magnifyingglass"
                    )
                    .font(.nova(15, .demibold))
                    .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }

                if hasFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.xxs + 2) {
                            ForEach(chipLabels, id: \.self) { label in
                                Text(label)
                                    .font(.nova(12, .demibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Theme.Colors.inset))
                            }
                        }
                    }
                    .scrollClipDisabled()
                } else {
                    Text("Browse homes for sale in Seattle and nearby")
                        .font(.nova(13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Small (half-width) card

    private func smallCard(icon: String, title: String, prompt: String) -> some View {
        EmptyStateCard { onSuggestionTap(prompt) } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Colors.brandRed)
                Spacer(minLength: Theme.Spacing.xs)
                Text(title)
                    .font(.nova(15, .demibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        }
    }

    // MARK: - Wide (full-width) card

    private func wideCard(icon: String, title: String, subtitle: String, prompt: String) -> some View {
        EmptyStateCard { onSuggestionTap(prompt) } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Colors.brandRed)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.nova(15, .demibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.nova(13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Filter helpers

    private func filterChipLabels(for filters: SearchFilters) -> [String] {
        var labels: [String] = []
        if let neighborhoods = filters.neighborhoods, !neighborhoods.isEmpty {
            labels.append(contentsOf: neighborhoods.prefix(2))
        }
        if let minBeds = filters.minBeds, minBeds > 0 {
            labels.append("\(minBeds)+ bd")
        }
        if let minBaths = filters.minBaths, minBaths > 0 {
            let baths = minBaths == minBaths.rounded() ? "\(Int(minBaths))" : String(format: "%.1f", minBaths)
            labels.append("\(baths)+ ba")
        }
        if filters.minPrice != nil || filters.maxPrice != nil {
            labels.append(priceChipLabel(min: filters.minPrice, max: filters.maxPrice))
        }
        if let type = filters.propertyType {
            labels.append(type)
        }
        if filters.isHotHome == true {
            labels.append("Hot homes")
        }
        return labels
    }

    private func priceChipLabel(min: Int?, max: Int?) -> String {
        switch (min, max) {
        case (let a?, let b?): return "\(formatPrice(a))–\(formatPrice(b))"
        case (let a?, nil): return "\(formatPrice(a))+"
        case (nil, let b?): return "Under \(formatPrice(b))"
        default: return "Price"
        }
    }

    private func formatPrice(_ value: Int) -> String {
        if value >= 1_000_000 {
            let m = Double(value) / 1_000_000.0
            return m == m.rounded() ? "$\(Int(m))M" : String(format: "$%.1fM", m)
        }
        return "$\(value / 1000)K"
    }

    private func buildResumePrompt(from filters: SearchFilters) -> String {
        var parts: [String] = []

        if let minBeds = filters.minBeds, minBeds > 0 {
            parts.append("\(minBeds)+ bedroom")
        }

        let typeWord = filters.propertyType?.lowercased() ?? "homes"
        parts.append(typeWord)

        if let max = filters.maxPrice {
            parts.append("under \(formatPrice(max))")
        } else if let min = filters.minPrice {
            parts.append("above \(formatPrice(min))")
        }

        if let neighborhoods = filters.neighborhoods, !neighborhoods.isEmpty {
            parts.append("in \(neighborhoods.joined(separator: ", "))")
        }

        if filters.isHotHome == true {
            parts.append("that are hot homes")
        }

        return "Find \(parts.joined(separator: " "))"
    }
}

// MARK: - Card container

private struct EmptyStateCard<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        }
        .buttonStyle(EmptyStateCardButtonStyle())
    }
}

private struct EmptyStateCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
