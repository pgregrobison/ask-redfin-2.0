import SwiftUI

/// Shared layout pieces for the two scripted confirmation cards, following
/// Redfin's "Confirmation" card pattern (Figma node 1651:10619): a checkmark
/// header, a message line, dividers, icon-titled content sections, and a
/// bottom CTA button.
private struct ConfirmationHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.Colors.brandGreen)
            Text(title)
                .font(.nova(17, .demibold))
                .foregroundStyle(Theme.Colors.brandGreen)
            Spacer()
        }
    }
}

private struct ConfirmationSectionTitle: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(Theme.Typography.secondaryBold)
            Spacer()
        }
    }
}

/// Bottom CTA button matching Figma's "View tour details" pattern. Decorative
/// only — the scripted demo doesn't wire it to real navigation.
private struct ConfirmationCTAButton: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.nova(14, .demibold))
            .foregroundStyle(Theme.Colors.invertedPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
            .background(Color.primary, in: Capsule())
    }
}

/// Shown in place of `TourRequestButton` once the Launch Demo autoplay
/// sequence "morphs" it into a result — a canned confirmation, not the real
/// multi-step tour flow.
struct ScriptedTourConfirmationCard: View {
    let confirmation: ScriptedTourConfirmation
    let allListings: [Listing]

    private var listing: Listing? {
        allListings.first { $0.id == confirmation.listingId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ConfirmationHeader(title: "Tour Confirmed")

            (
                Text("You're all set to see ")
                + Text(listing?.address ?? "the home").font(.nova(16, .demibold))
                + Text(" on \(confirmation.dateLabel) at \(confirmation.timeLabel). Your agent will meet you there.")
            )
            .font(Theme.Typography.secondary)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ConfirmationSectionTitle(icon: "calendar", title: "Tour details")

                Text("\(confirmation.dateLabel) \u{2022} \(confirmation.timeLabel)")
                    .font(Theme.Typography.secondaryBold)

                if let listing {
                    HStack(spacing: Theme.Spacing.sm) {
                        AsyncImage(url: URL(string: listing.photos.first ?? "")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color(.tertiarySystemFill)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: Theme.Radius.small))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(listing.address)
                                .font(Theme.Typography.captionBold)
                                .lineLimit(1)
                            Text(listing.formattedFullPrice)
                                .font(Theme.Typography.micro)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ConfirmationSectionTitle(icon: "person.crop.circle", title: "Touring agent")

                HStack(spacing: Theme.Spacing.sm) {
                    AsyncImage(url: URL(string: confirmation.agentPhotoURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(confirmation.agentName)
                            .font(Theme.Typography.captionBold)
                        Text("Your touring agent")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }

            Divider()

            ConfirmationCTAButton(title: "View tour details")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.widget))
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
    }
}

/// Shown in place of `MortgageRequestButton` once the Launch Demo autoplay
/// sequence "morphs" it into a result — Rocket Mortgage's own prequal-letter
/// card pattern (Figma node 1929:19840), not the app's usual neutral
/// confirmation-card style, since this represents a partner's branded letter
/// rather than a Redfin-native confirmation.
struct ScriptedMortgagePrequalCard: View {
    let confirmation: ScriptedMortgageConfirmation

    private var prequalifiedAmount: Int {
        confirmation.income * 4 + confirmation.downPayment
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.brandGreen)
                    Text("Prequalified for")
                        .font(.nova(14))
                        .foregroundStyle(.primary)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(formatCurrency(prequalifiedAmount))
                        .font(.nova(36, .demibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(confirmation.expiresLabel)
                        .font(.nova(12))
                        .foregroundStyle(.secondary.opacity(0.65))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                breakdownRow(label: "Down payment", value: formatCurrency(confirmation.downPayment))
                breakdownRow(label: "Rate / APR", value: confirmation.rateAPR)
                breakdownRow(label: "Loan type", value: confirmation.loanType)
            }

            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .bold))
                Text("View letter")
                    .font(.nova(16, .demibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.brandGreen, in: Capsule())
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.RocketCard.background, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.xl)
                .stroke(Theme.Colors.RocketCard.border, lineWidth: 1)
        }
        .padding(.leading, Theme.Spacing.md)
        .padding(.trailing, Theme.Spacing.md + Theme.Spacing.xl)
    }

    private func breakdownRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.nova(14))
            Spacer()
            Text(value)
                .font(.nova(14))
        }
        .foregroundStyle(.primary)
    }

    private func formatCurrency(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
