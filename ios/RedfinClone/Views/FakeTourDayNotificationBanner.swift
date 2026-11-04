import SwiftUI
import UIKit

struct FakeTourDayNotificationBanner: View {
    let onTap: () -> Void
    let onDismiss: () -> Void
    var onFrameChange: ((CGRect) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0
    @State private var appeared: Bool = false

    private static let appIconImage: UIImage? = {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let img = UIImage(named: last) {
            return img
        }
        return UIImage(named: "AppIcon") ?? UIImage(named: "icon")
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                iconView
                    .frame(width: 38, height: 38)
                    .clipShape(.rect(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("ASK REDFIN")
                            .font(.nova(13, .demibold))
                            .foregroundStyle(.primary)
                            .tracking(-0.1)
                        Spacer(minLength: 0)
                        Text("now")
                            .font(.nova(13))
                            .foregroundStyle(.secondary)
                    }
                    Text("Welcome to tour day!")
                        .font(.nova(15, .demibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("I've created a new thread for all things tours.")
                        .font(.nova(15))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
            .contentShape(.rect(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(BannerPressStyle())
        .padding(.horizontal, 8)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: BannerFrameKey.self, value: geo.frame(in: .global))
            }
        )
        .onPreferenceChange(BannerFrameKey.self) { frame in
            onFrameChange?(frame)
        }
        .scaleEffect(appeared ? 1 : 0.94, anchor: .top)
        .offset(y: appeared ? min(dragOffset, 8) : -180)
        .opacity(appeared ? 1 : 0)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    if value.translation.height < -30 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(for: .seconds(5))
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let img = Self.appIconImage {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image("RedfinLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            appeared = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(260))
            onDismiss()
        }
    }
}

private struct BannerFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct BannerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
