import SwiftUI

// MARK: - Toggle

/// 52×32 slide switch; the track turns green when on.
struct NovaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(configuration.isOn ? Nova.Color.green600 : Nova.Color.gray300)
                .frame(width: 52, height: 32)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .novaElevation(.level2)
                        .padding(4)
                }
                .onTapGesture {
                    withAnimation(Nova.Motion.easeOut()) { configuration.isOn.toggle() }
                }
                .sensoryFeedback(.selection, trigger: configuration.isOn)
                .accessibilityAddTraits(.isButton)
        }
    }
}

extension ToggleStyle where Self == NovaToggleStyle {
    static var nova: NovaToggleStyle { NovaToggleStyle() }
}

// MARK: - Text field

/// Floating-label text input. Filled by default (gray-50); `outline` is white
/// with a hairline that darkens on focus.
struct NovaTextField: View {
    let label: String
    @Binding var text: String
    var hint: String? = nil
    var outline = false
    var keyboard: UIKeyboardType = .default

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Nova.Typography.label12)
                    .foregroundStyle(Nova.Color.textSubtle)
                TextField("", text: $text)
                    .font(.nova(16))
                    .foregroundStyle(Nova.Color.text)
                    .tint(Nova.Color.brandFixed)
                    .keyboardType(keyboard)
                    .focused($focused)
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)
            .padding(.bottom, 11)
            .background(fill, in: RoundedRectangle(cornerRadius: Nova.Radius.field))
            .overlay {
                if outline {
                    RoundedRectangle(cornerRadius: Nova.Radius.field)
                        .strokeBorder(focused ? Nova.Color.text : Nova.Color.overlay, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .animation(Nova.Motion.easeInOut(), value: focused)

            if let hint {
                Text(hint)
                    .font(Nova.Typography.body14)
                    .foregroundStyle(Nova.Color.textSubtle)
                    .padding(.leading, 16)
            }
        }
    }

    private var fill: Color {
        if outline { return Nova.Color.bgPrimary }
        return focused ? Nova.Color.bgTertiary : Nova.Color.bgSecondary
    }
}
