import SwiftUI

/// The Dream Home Sorter: a swipe deck of suggestions. Drag right for a
/// must-have, left for a nice-to-have, down for a deal-breaker, or tap a
/// zone. Skip, undo, a short intro demo, then a summary to save.
struct DreamSorterView: View {
    let items: [DreamRecommendation]
    let onSave: ([SearchState.DreamBucket: [DreamRecommendation]]) -> Void
    let onClose: () -> Void

    private typealias Bucket = SearchState.DreamBucket

    @State private var index = 0
    @State private var placed: [(item: DreamRecommendation, bucket: Bucket?)] = []
    @State private var offset: CGSize = .zero
    @State private var dragging = false
    @State private var flyOut: CGSize?
    @State private var demoTask: Task<Void, Never>?
    @State private var touched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let niceColor = Color(red: 94 / 255, green: 121 / 255, blue: 217 / 255)
    private static let mustColor = Color(white: 0.067)
    private static let dealColor = Color(red: 222 / 255, green: 51 / 255, blue: 65 / 255)

    private var done: Bool { index >= items.count }
    private var current: DreamRecommendation? { done ? nil : items[index] }
    private func bucket(_ b: Bucket) -> [DreamRecommendation] { placed.filter { $0.bucket == b }.map(\.item) }

    /// Which zone the card is over.
    private var zone: Bucket? {
        if offset.height > 90 && offset.height > 0.8 * abs(offset.width) { return .deal }
        if offset.width > 70 { return .must }
        if offset.width < -70 { return .nice }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if done { summary } else { deck }
        }
        .background(Nova.Color.bgPrimary.ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: zone) { _, z in z != nil }
        .onAppear { startDemo() }
        .onDisappear { demoTask?.cancel() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button { undo() } label: {
                    NovaIcon("refresh", size: 18).foregroundStyle(Nova.Color.text)
                        .frame(width: 36, height: 36).background(Nova.Color.bgSecondary, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(placed.isEmpty)
                .opacity(placed.isEmpty ? 0.35 : 1)
                .accessibilityLabel("Undo")
                ProgressView(value: Double(min(index, items.count)), total: Double(max(items.count, 1)))
                    .tint(Nova.Color.gray800)
                    .animation(.easeOut(duration: 0.4), value: index)
                Text("\(min(index + 1, items.count)) of \(items.count)").font(.nova(13, .medium)).foregroundStyle(Nova.Color.textSubtle)
                    .monospacedDigit()
                Button(action: onClose) {
                    NovaIcon("close", size: 18).foregroundStyle(Nova.Color.text)
                        .frame(width: 36, height: 36).background(Nova.Color.bgSecondary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            if !done {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sort what I noticed").font(.nova(24, .medium)).tracking(-0.5).foregroundStyle(Nova.Color.text)
                    Text("Drag each one where it belongs.").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: Deck

    private var deck: some View {
        GeometryReader { geo in
            let cardH = min(max(geo.size.height - 300, 190), 300)
            ZStack {
                // Zones (also tappable).
                HStack {
                    zoneStrip(.nice, "Nice", Self.niceColor)
                    Spacer()
                    zoneStrip(.must, "Must", Self.mustColor)
                }
                .padding(.bottom, 128)
                VStack { Spacer(); dealSheet }

                // Next card peeks behind.
                if index + 1 < items.count {
                    let t = min(hypot(offset.width, offset.height) / 140, 1)
                    card(items[index + 1], height: cardH)
                        .scaleEffect(0.94 + 0.06 * t)
                        .offset(y: 16 * (1 - t))
                        .opacity(0.55 + 0.45 * t)
                }
                if let current {
                    card(current, height: cardH, stamp: zone)
                        .scaleEffect(dragging ? (zone != nil ? 0.97 : 1.02) : 1)
                        .rotationEffect(.degrees(Double(offset.width) * 0.07))
                        .offset(flyOut ?? offset)
                        .opacity(flyOut == nil ? 1 : 0.2)
                        .gesture(drag)
                        .accessibilityElement(children: .combine)
                        .accessibilityActions {
                            Button("Must-have") { commit(.must) }
                            Button("Nice-to-have") { commit(.nice) }
                            Button("Deal-breaker") { commit(.deal) }
                            Button("Skip") { skip() }
                        }
                        .id(current.id)
                        .transition(.scale(scale: 0.94).combined(with: .offset(y: 16)).combined(with: .opacity))
                }
                VStack {
                    Spacer()
                    Button("Skip") { skip() }
                        .buttonStyle(.novaLink)
                        .padding(.bottom, 170)
                }
            }
            .padding(.top, 12)
        }
    }

    private func card(_ r: DreamRecommendation, height: CGFloat, stamp: Bucket? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(r.criterion.capitalizedFirst).font(.nova(28, .medium)).tracking(-0.6).foregroundStyle(Nova.Color.text)
            Text(r.evidence).font(.nova(15)).lineSpacing(4).foregroundStyle(Nova.Color.textSubtle)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(Nova.Color.bgPrimary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Nova.Color.border, lineWidth: 1))
        .shadow(color: .black.opacity(dragging ? 0.18 : 0.08), radius: dragging ? 24 : 15, y: dragging ? 24 : 10)
        .overlay(alignment: stamp == .must ? .topLeading : stamp == .nice ? .topTrailing : .top) {
            if let stamp { stampView(stamp).padding(14) }
        }
        .padding(.horizontal, 72)
        .frame(maxHeight: .infinity, alignment: .center)
        .padding(.bottom, 140)
    }

    private func stampView(_ b: Bucket) -> some View {
        let (text, color, angle): (String, Color, Double) = switch b {
        case .must: ("MUST", Self.mustColor, -8)
        case .nice: ("NICE", Self.niceColor, 8)
        case .deal: ("DEAL-BREAKER", Self.dealColor, 0)
        }
        return Text(text).font(.nova(13, .bold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 2))
            .rotationEffect(.degrees(angle))
            .transition(.scale.combined(with: .opacity))
    }

    private func zoneStrip(_ b: Bucket, _ label: String, _ color: Color) -> some View {
        let hot = zone == b, width: CGFloat = hot ? 92 : dragging ? 64 : 52
        return Button { commit(b) } label: {
            VStack(spacing: 10) {
                countDot(bucket(b).count, color, hot)
                Text(label).font(.nova(13, .medium)).rotationEffect(.degrees(b == .nice ? -90 : 90)).fixedSize()
                Spacer()
            }
            .padding(.top, 14)
            .foregroundStyle(hot ? .white : color)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(hot ? color : color.opacity(0.06), in: UnevenRoundedRectangle(
                topLeadingRadius: b == .must ? 20 : 0, bottomLeadingRadius: b == .must ? 20 : 0,
                bottomTrailingRadius: b == .nice ? 20 : 0, topTrailingRadius: b == .nice ? 20 : 0))
            .overlay(UnevenRoundedRectangle(
                topLeadingRadius: b == .must ? 20 : 0, bottomLeadingRadius: b == .must ? 20 : 0,
                bottomTrailingRadius: b == .nice ? 20 : 0, topTrailingRadius: b == .nice ? 20 : 0)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(.plain)
        .padding(.top, 60)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: width)
        .accessibilityLabel(b == .must ? "Must-have" : "Nice-to-have")
    }

    private var dealSheet: some View {
        let hot = zone == .deal, height: CGFloat = hot ? 152 : dragging ? 120 : 108
        return Button { commit(.deal) } label: {
            HStack(spacing: 10) {
                countDot(bucket(.deal).count, Self.dealColor, hot)
                Text("Deal-breaker").font(.nova(15, .medium))
            }
            .foregroundStyle(hot ? .white : Self.dealColor)
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .center)
            .background(hot ? Self.dealColor : Self.dealColor.opacity(0.06), in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28).strokeBorder(Self.dealColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: height)
        .accessibilityLabel("Deal-breaker")
    }

    private func countDot(_ n: Int, _ color: Color, _ hot: Bool) -> some View {
        Text("\(n)").font(.nova(13, .demibold)).monospacedDigit()
            .foregroundStyle(hot ? color : .white)
            .frame(width: 28, height: 28)
            .background(hot ? .white : color, in: Circle())
            .contentTransition(.numericText())
    }

    // MARK: Gestures

    private var drag: some Gesture {
        DragGesture()
            .onChanged { g in
                stopDemo()
                dragging = true
                offset = g.translation
            }
            .onEnded { _ in
                dragging = false
                if let z = zone { commit(z) } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { offset = .zero }
                }
            }
    }

    private func commit(_ b: Bucket) {
        guard let current else { return }
        stopDemo()
        let out: CGSize = b == .deal ? CGSize(width: 0, height: 420) : CGSize(width: b == .must ? 300 : -300, height: offset.height)
        withAnimation(.easeIn(duration: 0.34)) { flyOut = out }
        placed.append((current, b))
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            flyOut = nil
            offset = .zero
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { index += 1 }
        }
    }

    private func skip() {
        guard let current else { return }
        stopDemo()
        withAnimation(.easeOut(duration: 0.23)) { flyOut = CGSize(width: 0, height: -40) }
        placed.append((current, nil))
        Task {
            try? await Task.sleep(for: .milliseconds(230))
            flyOut = nil
            offset = .zero
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { index += 1 }
        }
    }

    private func undo() {
        guard let last = placed.popLast() else { return }
        let from: CGSize = switch last.bucket {
        case .must: CGSize(width: 300, height: 0)
        case .nice: CGSize(width: -300, height: 0)
        case .deal: CGSize(width: 0, height: 420)
        case nil: CGSize(width: 0, height: -40)
        }
        index = max(0, index - 1)
        offset = from
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { offset = .zero }
    }

    // MARK: Intro demo

    /// Shows the three directions once, unless you touch the card first.
    private func startDemo() {
        guard !reduceMotion, !touched, !items.isEmpty else { return }
        demoTask = Task {
            let steps: [(Int, CGSize)] = [(700, CGSize(width: -54, height: 0)), (650, CGSize(width: 54, height: 0)),
                                         (650, CGSize(width: 0, height: 56)), (650, .zero)]
            for (wait, to) in steps {
                try? await Task.sleep(for: .milliseconds(wait))
                guard !Task.isCancelled else { return }
                withAnimation(.timingCurve(0.33, 1, 0.68, 1, duration: 0.55)) { offset = to }
            }
        }
    }

    private func stopDemo() {
        guard !touched else { return }
        touched = true
        demoTask?.cancel()
    }

    // MARK: Summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Here’s how you sorted them").font(.nova(24, .medium)).tracking(-0.5).foregroundStyle(Nova.Color.text)
            group(.must, "Must-haves", Self.mustColor, delay: 0)
            group(.nice, "Nice-to-haves", Self.niceColor, delay: 0.09)
            group(.deal, "Deal-breakers", Self.dealColor, delay: 0.18)
            Spacer()
            Button {
                onSave([.must: bucket(.must), .nice: bucket(.nice), .deal: bucket(.deal)])
            } label: { Text("Save to my dream home").frame(maxWidth: .infinity) }
                .buttonStyle(.nova(.primary, size: .large, fullWidth: true))
            Button("Sort again") {
                placed = []
                withAnimation { index = 0 }
            }
            .buttonStyle(.novaLink)
            .frame(maxWidth: .infinity)
        }
        .padding(EdgeInsets(top: 32, leading: 20, bottom: 34, trailing: 20))
    }

    private func group(_ b: Bucket, _ title: String, _ color: Color, delay: Double) -> some View {
        let xs = bucket(b)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title).font(.nova(18, .medium)).foregroundStyle(Nova.Color.text)
                Text("\(xs.count)").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
            }
            if xs.isEmpty {
                Text("Nothing here yet").font(Nova.Typography.body14).foregroundStyle(Nova.Color.textSubtle)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(xs) { r in
                        Text(r.criterion.capitalizedFirst).font(Nova.Typography.label14).foregroundStyle(Nova.Color.text)
                            .padding(.horizontal, 12).frame(height: 34).background(Nova.Color.bgSecondary, in: Capsule())
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .offset(y: 10)).animation(.easeOut(duration: 0.4).delay(delay)))
    }
}
