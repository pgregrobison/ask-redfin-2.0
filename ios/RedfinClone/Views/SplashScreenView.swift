import SwiftUI

struct SplashScreenView: View {
    @Binding var accessoryMidY: CGFloat
    var onChromeReady: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var typedText = ""
    @State private var showCursor = false
    @State private var contentOpacity: Double = 0
    @State private var redOpacity: Double = 1
    @State private var chromeBlockOpacity: Double = 1
    @State private var panOffset: CGFloat = 0
    @State private var screenW: CGFloat = 0
    @State private var screenH: CGFloat = 0
    @State private var safeBottom: CGFloat = 0
    @State private var fontSize: CGFloat = 0

    // crossfade: 0 = typing view visible, 1 = pill view visible
    @State private var pillProgress: Double = 0
    // pill view zoom-out (starts large to match typed text size, springs to 1.0)
    @State private var pillScale: CGFloat = 1.0
    // pill view vertical offset (moves to accessory bar position)
    @State private var pillOffsetY: CGFloat = 0

    private let sentence1 = "Find your dream."
    private let sentence2 = " Just ask Redfin"
    private var fullText: String { sentence1 + sentence2 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.Colors.brandRed
                    .ignoresSafeArea()
                    .opacity(redOpacity)

                VStack(spacing: 0) {
                    Spacer()
                    Theme.Colors.brandRed
                        .frame(height: geo.safeAreaInsets.bottom + 140)
                        .ignoresSafeArea(edges: .bottom)
                }
                .opacity(chromeBlockOpacity)

                // ── Typing layer — fades out as pill fades in ─────────────────
                ZStack(alignment: .leading) {
                    Color.clear
                    typingContent(geo: geo)
                }
                .opacity(1.0 - pillProgress)
                .opacity(contentOpacity)

                // ── Pill layer — matches the Ask Redfin accessory bar exactly ─
                pillAccessoryView(screenW: geo.size.width)
                    .scaleEffect(pillScale)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .offset(y: pillOffsetY)
                    .opacity(pillProgress)
                    .opacity(contentOpacity)
            }
            .onAppear {
                screenW    = geo.size.width
                screenH    = geo.size.height
                safeBottom = geo.safeAreaInsets.bottom
                fontSize   = computeFontSize(screenW: geo.size.width)
            }
        }
        .ignoresSafeArea()
        .task { await run() }
    }

    // MARK: - Typing content

    private func typingContent(geo: GeometryProxy) -> some View {
        let fs         = fontSize > 0 ? fontSize : computeFontSize(screenW: geo.size.width)
        let iconSize   = ceil(fs * 0.52)
        let spacing    = ceil(fs * 0.22)
        let leftMargin = geo.size.width * 0.08
        // Smoothly transition from white (on red) to black (inside the pill)
        let fg         = Color(white: 1.0 - pillProgress)

        return HStack(spacing: spacing) {
            Image(systemName: "sparkle")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(fg)

            HStack(spacing: 2) {
                Text(typedText)
                    .font(.system(size: fs, weight: .regular))
                    .foregroundStyle(fg)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .animation(nil, value: typedText)

                RoundedRectangle(cornerRadius: 1)
                    .fill(fg)
                    .frame(width: 2, height: fs * 0.72)
                    .opacity(showCursor ? 1 : 0)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.leading, leftMargin)
        .offset(x: -panOffset)
    }

    // MARK: - Pill view (identical layout to AskRedfinAccessoryBar)

    @ViewBuilder
    private func pillAccessoryView(screenW: CGFloat) -> some View {
        let content = ZStack {
            // Text centred — matches the accessory bar placeholder style
            Text(fullText)
                .font(Theme.Typography.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Sparkle at leading edge — matches the accessory bar icon position
            HStack {
                Image(systemName: "sparkle")
                    .font(.system(size: Theme.ButtonSize.iconSize, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.leading, Theme.Spacing.md)
        }
        .frame(width: screenW - 32, height: 50)

        if #available(iOS 26.0, *) {
            content.glassEffect(in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }

    // MARK: - Font sizing

    private func computeFontSize(screenW: CGFloat) -> CGFloat {
        let target = screenW * 0.70
        for s in stride(from: CGFloat(16), through: CGFloat(120), by: CGFloat(0.5)) {
            let f = UIFont.systemFont(ofSize: s)
            let w = ceil((sentence1 as NSString).size(withAttributes: [.font: f]).width)
            if w >= target { return s }
        }
        return 36
    }

    // MARK: - Pan

    private func updatePan(text: String) {
        guard screenW > 0, fontSize > 0 else { return }
        let fs          = fontSize
        let iconSize    = ceil(fs * 0.52)
        let spacing     = ceil(fs * 0.22)
        let leftMargin  = screenW * 0.08
        let targetX     = screenW * 0.90
        let approxIconW = iconSize * 0.88
        let font  = UIFont.systemFont(ofSize: fs)
        let textW = text.isEmpty ? 0 : ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let cursorWorldX = leftMargin + approxIconW + spacing + textW
        withAnimation(.easeOut(duration: 0.08)) {
            panOffset = max(0, cursorWorldX - targetX)
        }
    }

    // MARK: - Sequence

    private func run() async {
        try? await Task.sleep(for: .milliseconds(550))

        withAnimation(.easeIn(duration: 0.45)) { contentOpacity = 1 }
        try? await Task.sleep(for: .milliseconds(550))

        for _ in 0..<3 {
            showCursor = true
            try? await Task.sleep(for: .milliseconds(530))
            showCursor = false
            try? await Task.sleep(for: .milliseconds(430))
        }
        showCursor = true
        try? await Task.sleep(for: .milliseconds(180))

        for char in sentence1 {
            if Task.isCancelled { return }
            typedText.append(char)
            updatePan(text: typedText)
            let ms: Int = switch char {
            case " ":  Int.random(in: 38...55)
            case ".":  Int.random(in: 45...65)
            default:   Int.random(in: 22...42)
            }
            try? await Task.sleep(for: .milliseconds(ms))
        }

        try? await Task.sleep(for: .milliseconds(1200))

        for char in sentence2 {
            if Task.isCancelled { return }
            typedText.append(char)
            updatePan(text: typedText)
            let ms: Int = switch char {
            case " ":  Int.random(in: 38...55)
            default:   Int.random(in: 22...40)
            }
            try? await Task.sleep(for: .milliseconds(ms))
        }

        // Hold
        try? await Task.sleep(for: .milliseconds(900))
        showCursor = false
        try? await Task.sleep(for: .milliseconds(160))

        // Prime the pill at the same visual scale as the large typed text,
        // so the crossfade feels like a seamless continuation
        pillScale = max(1.4, fontSize / 17.0)
        try? await Task.sleep(for: .milliseconds(16))   // one frame to pick up initial scale

        // Crossfade: typing content fades out, pill view fades in at large scale
        withAnimation(.easeInOut(duration: 0.40)) { pillProgress = 1 }
        // Simultaneously: pill springs to true size (zoom-out)
        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) { pillScale = 1.0 }

        // Wait for zoom to settle — full-size pill visible at screen centre
        try? await Task.sleep(for: .milliseconds(750))

        // Pill moves to the accessory bar position; red dissolves as it travels
        let target = accessoryMidY > 0
            ? accessoryMidY
            : screenH - safeBottom - 83 - 25

        withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
            pillOffsetY = target - screenH * 0.5
        }
        withAnimation(.easeInOut(duration: 0.68)) {
            redOpacity = 0
            chromeBlockOpacity = 0
        }

        // Wait for spring to settle
        try? await Task.sleep(for: .milliseconds(700))

        // Pill fades — real accessory bar beneath takes over
        withAnimation(.easeInOut(duration: 0.32)) { contentOpacity = 0 }
        onChromeReady()

        try? await Task.sleep(for: .milliseconds(360))
        dismiss()
    }
}
