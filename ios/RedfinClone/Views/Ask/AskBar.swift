import SwiftUI

/// The shared Ask Redfin bar shown over Find (and later My home). Tapping the
/// field starts the keyboard composer; the leading chevron opens the chat.
/// While a request runs it glows and shows the current step; afterwards it
/// shows the confirmation for 5s.
///
/// In the iOS 26 tab bar accessory the system provides the glass capsule;
/// elsewhere `standalone` draws one.
struct AskBar: View {
    @Bindable var session: AskSession
    var standalone = false
    var compact = false

    @State private var placeholderIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            if !compact {
                Button { session.openChat() } label: {
                    NovaIcon("expand_less", size: 24)
                        .foregroundStyle(Nova.Color.text)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show chat history")
                .disabled(session.isBusy)
                .opacity(session.isBusy ? 0 : 1)
                .frame(width: session.isBusy ? 0 : 44)
            } else {
                NovaIcon("star_shining", size: 20).padding(.leading, 12)
            }

            Button { startComposing() } label: {
                ZStack(alignment: .leading) {
                    if let toast = session.barToast {
                        AskToastLabel(toast: toast)
                            .transition(.opacity)
                    } else {
                        Text(session.draft.isEmpty ? placeholder : session.draft)
                            .font(Nova.Typography.body16)
                            .foregroundStyle(session.draft.isEmpty ? Nova.Color.textSubtle : Nova.Color.text)
                            .lineLimit(1)
                            .id(placeholderIndex)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 6)), removal: .opacity.combined(with: .offset(y: -6))))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.leading, compact ? 4 : 0)
                .padding(.trailing, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.barToast.map(Self.accessibilityText) ?? "Ask Redfin")
            .accessibilityHint("Describe the home you want")
        }
        .padding(.horizontal, standalone ? 6 : 4)
        .frame(height: standalone ? 56 : nil)
        .background {
            if standalone { Color.clear.novaGlass(in: Capsule(), interactive: true) }
        }
        .overlay { if session.isBusy { AskGlowRing() } }
        .animation(Nova.Motion.easeOut(), value: session.isBusy)
        .animation(.easeInOut(duration: 0.3), value: placeholderIndex)
        .animation(.easeInOut(duration: 0.32), value: session.barToast)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.6))
                if session.barToast == nil && session.draft.isEmpty { placeholderIndex += 1 }
            }
        }
    }

    private var placeholder: String {
        session.placeholders[placeholderIndex % session.placeholders.count]
    }

    private func startComposing() {
        guard !session.isBusy else { return }
        session.clearBubble()
        session.isComposing = true
    }

    private static func accessibilityText(_ t: AskBarToast) -> String {
        switch t {
        case .thinking(let s): "Working: \(s)"
        case .done(let s): "Done: \(s)"
        }
    }
}

/// Thinking: a pulsing sparkle and shimmering step label. Done: a check and
/// the confirmation.
struct AskToastLabel: View {
    let toast: AskBarToast
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            switch toast {
            case .thinking(let label):
                NovaIcon("star_shining", size: 20)
                    .foregroundStyle(Nova.Color.brandFixed)
                    .scaleEffect(pulse ? 1.1 : 0.8)
                    .rotationEffect(.degrees(pulse ? 90 : 0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }
                ShimmerText(text: label)
                    .contentTransition(.opacity)
            case .done(let title):
                NovaIcon("check", size: 20).foregroundStyle(Nova.Color.text)
                Text(title)
                    .font(Nova.Typography.label14)
                    .foregroundStyle(Nova.Color.text)
                    .lineLimit(1)
            }
        }
    }
}

/// Text with a light band sweeping across it (`rx-shimmer`, 1.6s).
struct ShimmerText: View {
    let text: String
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(Nova.Typography.label14)
            .foregroundStyle(Nova.Color.textSubtle)
            .lineLimit(1)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, Nova.Color.text, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.5)
                            .offset(x: phase * geo.size.width * 1.5)
                    }
                    .mask(Text(text).font(Nova.Typography.label14).lineLimit(1))
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

/// The animated AI edge while busy: a warm-to-red gradient sweeping around
/// the capsule, with a soft bloom.
struct AskGlowRing: View {
    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var gradient: AngularGradient {
        AngularGradient(colors: [Color(red: 254 / 255, green: 230 / 255, blue: 194 / 255), Nova.Color.brandFixed,
                                 Color(red: 254 / 255, green: 197 / 255, blue: 179 / 255), Color(red: 254 / 255, green: 230 / 255, blue: 194 / 255)],
                        center: .center, angle: .degrees(angle))
    }

    var body: some View {
        ZStack {
            Capsule().stroke(gradient, lineWidth: 6).blur(radius: 5).opacity(0.8)
            Capsule().stroke(gradient, lineWidth: 2).blur(radius: 1)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4.6).repeatForever(autoreverses: false)) { angle = 360 }
        }
        .accessibilityHidden(true)
    }
}

/// Keyboard composer over the map: a glass field riding the keyboard, with a
/// spring-in send button. Submitting runs the request in bar mode.
struct AskComposer: View {
    @Bindable var session: AskSession
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { session.isComposing = false }
            HStack(spacing: 8) {
                NovaIcon("star_shining", size: 20).padding(.leading, 12)
                TextField("Describe the home you want", text: $session.draft)
                    .font(Nova.Typography.body16)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { session.submitDraft() }
                AskSendButton(isVisible: !session.draft.trimmingCharacters(in: .whitespaces).isEmpty) {
                    session.submitDraft()
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 56)
            .novaGlass(in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear { focused = true }
        .onChange(of: focused) { _, f in if !f { session.isComposing = false } }
    }
}

/// 40pt near-black circle with an up arrow that springs in when there's text.
struct AskSendButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NovaIcon("arrow_upward", size: 20)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(white: 0.067), in: Circle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isVisible ? 1 : 0.6)
        .opacity(isVisible ? 1 : 0)
        .frame(width: isVisible ? 40 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVisible)
        .accessibilityLabel("Send")
        .disabled(!isVisible)
    }
}

/// The reply streaming into a glass bubble above the bar while the chat is
/// closed. Tap to open the chat; press and hold to keep it up.
struct AskReplyBubble: View {
    @Bindable var session: AskSession

    var body: some View {
        if let text = session.bubbleText {
            Text(AskFormatting.attributed(text, revealed: session.bubbleRevealed))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .novaGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                .contentShape(RoundedRectangle(cornerRadius: 20))
                .onTapGesture { session.openChat() }
                .onLongPressGesture(minimumDuration: 0.2, pressing: { session.holdBubble($0) }, perform: {})
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .offset(y: 12)))
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the chat")
        }
    }
}
