import SwiftUI

/// Matches the desktop prototype's map pin (Figma node 1927:19593): a flat
/// green capsule with a small pointer tail. The desktop design doesn't
/// distinguish "seen" homes, so that state now shares the same green
/// treatment — only the actively-selected pin still gets its own (red, no
/// tail) highlight, since losing that would make it harder to tell which
/// home is selected on the map.
struct MapPinView: View {
    let listing: Listing
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if isSelected {
                selectedPin
            } else {
                defaultPin
            }
        }
        .padding(Theme.MapPin.outerPadding)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private var selectedPin: some View {
        Text(listing.formattedPrice)
            .font(.novaFixed(Theme.IconSize.mapPin, .demibold))
            .tracking(-0.3)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.MapPin.horizontalPadding)
            .padding(.vertical, Theme.Spacing.xxs + 2)
            .background(
                colorScheme == .dark ? Theme.Colors.MapPin.selectedDark : Theme.Colors.MapPin.selectedLight,
                in: Capsule()
            )
            .shadow(color: Theme.Shadow.subtleColor, radius: Theme.Shadow.subtleRadius, y: Theme.Shadow.subtleY)
    }

    private var defaultPin: some View {
        VStack(spacing: 0) {
            Text(listing.formattedPrice)
                .font(.novaFixed(Theme.IconSize.mapPin, .medium))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.MapPin.horizontalPadding)
                .padding(.vertical, Theme.Spacing.xxs + 2)
                .background(Theme.Colors.brandGreen, in: Capsule())

            PinTail()
                .fill(Theme.Colors.brandGreen)
                .frame(width: 10, height: 6)
        }
        .shadow(color: Theme.Shadow.subtleColor, radius: Theme.Shadow.subtleRadius, y: Theme.Shadow.subtleY)
    }
}

/// Small downward-pointing triangle beneath the pin's price pill.
private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
