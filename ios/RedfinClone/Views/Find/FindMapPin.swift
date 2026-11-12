import SwiftUI

/// The iOS Vision price pin: a near-black price pill for the top 100 homes,
/// a 12pt dot for the rest. Selected homes turn brand red at 1.15×;
/// homes the chat points at turn red at 1.25× with a glow. With an analysis
/// on, the pill takes its color from the ramp.
struct FindMapPin: View {
    let label: String
    let isPill: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    /// Analysis ramp colors; `noValue` grays the pin out.
    var analysis: (fill: Color, text: Color)? = nil
    var analysisNoValue = false

    private var fill: Color {
        if isSelected || isHighlighted { return Nova.Color.brandFixed }
        if analysisNoValue { return Nova.Color.gray200 }
        return analysis?.fill ?? Color(white: 0.067)
    }

    private var textColor: Color {
        if isSelected || isHighlighted { return .white }
        if analysisNoValue { return Nova.Color.gray800 }
        return analysis?.text ?? .white
    }

    private var scale: CGFloat { isHighlighted ? 1.25 : isSelected ? 1.15 : 1 }

    var body: some View {
        Group {
            if isPill || isSelected || isHighlighted {
                Text(label)
                    .font(.novaFixed(12, .medium))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(fill, in: Capsule())
            } else {
                Circle()
                    .fill(fill)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
        }
        .background {
            if isHighlighted {
                Capsule()
                    .stroke(.white, lineWidth: 2)
                    .shadow(color: Nova.Color.brandFixed.opacity(0.55), radius: 14)
                    .overlay(Capsule().stroke(Nova.Color.brandFixed.opacity(0.35), lineWidth: 4).padding(-3))
            }
        }
        .novaElevation(.level2)
        .scaleEffect(scale, anchor: isPill ? .bottom : .center)
        .padding(6)
        .contentShape(Rectangle())
        .animation(Nova.Motion.easeOut(), value: scale)
        .accessibilityLabel(label)
    }
}
