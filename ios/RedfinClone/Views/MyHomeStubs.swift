import SwiftUI

// MARK: - Draft model

@Observable
final class OTOSetupDraft {
    var hasActiveDraft: Bool = false

    func clear() {
        hasActiveDraft = false
    }
}

// MARK: - Three dots loading indicator

struct ThreeDotsLoading: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .opacity(phase == i ? 1 : 0.35)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: false)) {
                phase = (phase + 1) % 3
            }
            Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = (phase + 1) % 3
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder sheets

struct OTOSetupView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "house.and.flag")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Open to Offers Setup")
                    .font(Theme.Typography.sectionTitle)
                Text("This is a placeholder for the setup flow.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("Activate")
                        .font(.inter(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 222/255, green: 51/255, blue: 65/255))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
            }
            .padding()
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct OTOSetupFlowView: View {
    @Bindable var draft: OTOSetupDraft
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Setup flow")
                    .font(Theme.Typography.sectionTitle)
                Text("Multi-step flow placeholder. Save a draft or activate.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    Button {
                        draft.hasActiveDraft = true
                        dismiss()
                    } label: {
                        Text("Save draft")
                            .font(.inter(16, .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(Capsule().stroke(Color.primary, lineWidth: 1))
                    }
                    Button {
                        draft.hasActiveDraft = false
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Activate listing")
                            .font(.inter(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 222/255, green: 51/255, blue: 65/255))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding()
            .navigationTitle("Open to Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct OTONextStepsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Label("Review your offers", systemImage: "envelope.open")
                Label("List on the open market", systemImage: "house")
                Label("Talk to an agent", systemImage: "person.2")
                Label("Pause your listing", systemImage: "pause.circle")
            }
            .navigationTitle("Next steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct OTOOffersSheetView: View {
    let isOwnerB: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Submitted offers") {
                    offerRow(buyer: "Buyer in Ballard", price: "$892K")
                    offerRow(buyer: "Buyer in Fremont", price: "$1.01M")
                    offerRow(buyer: "Buyer in Queen Anne", price: "$938K")
                }
            }
            .navigationTitle("Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func offerRow(buyer: String, price: String) -> some View {
        HStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(buyer).font(.inter(15, .semibold))
                Text("Submitted today").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(price).font(.inter(16, .bold)).monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Asset placeholders (until art is provided)

struct MarketGaugePlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let lightURL = URL(string: "https://r2-pub.rork.com/generated-images/d1dde4b8-fe41-48e9-a7fc-d5068ac827b3.png")
    private static let darkURL  = URL(string: "https://r2-pub.rork.com/generated-images/66152ea8-5f5d-416c-aa08-d2989d398279.png")

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: colorScheme == .dark ? Self.darkURL : Self.lightURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.clear
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)

            HStack {
                Text("Buyer's").font(Theme.Typography.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Balanced").font(.inter(12, .semibold)).foregroundStyle(.primary)
                Spacer()
                Text("Seller's").font(Theme.Typography.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ReimagineSpacePlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let lightURL = URL(string: "https://r2-pub.rork.com/generated-images/63b7a663-d01f-4f46-8b3b-174b160622e8.png")
    private static let darkURL  = URL(string: "https://r2-pub.rork.com/generated-images/a9b1a488-d353-44a3-87bf-5d17da0dde37.png")

    var body: some View {
        Color(.tertiarySystemFill)
            .frame(height: 180)
            .overlay {
                AsyncImage(url: colorScheme == .dark ? Self.darkURL : Self.lightURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    VStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
