import SwiftUI

struct StaleChatWidget: View {
    let onNewChat: () -> Void

    @State private var resolved = false
    @State private var choseNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if resolved {
                resolvedView
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            } else {
                actions
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .background(Theme.Colors.secondaryBackground)
        .clipShape(.rect(cornerRadius: Theme.Radius.widget))
        .padding(.horizontal, Theme.Spacing.md)
        .animation(.snappy(duration: 0.35), value: resolved)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("This chat looks stale")
                    .font(.headline)
                Text("Pick up where you left off or start fresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.md)
    }

    // MARK: - Action buttons

    private var actions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Start new chat (primary)
            Button {
                choseNew = true
                resolved = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onNewChat()
                }
            } label: {
                HStack(spacing: Theme.Spacing.xxs + 2) {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New chat")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(Theme.Colors.invertedPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
                .background(Color.primary, in: Capsule())
            }
            .buttonStyle(StaleChatActionButtonStyle())

            // Continue (outline)
            Button {
                choseNew = false
                resolved = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: Theme.Spacing.xxs + 2) {
                    Image(systemName: "arrow.forward")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Continue")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.ButtonSize.compactVerticalPadding)
                .background(
                    Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1.5)
                )
            }
            .buttonStyle(StaleChatActionButtonStyle())
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }

    // MARK: - Resolved state

    private var resolvedView: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: choseNew ? "plus.bubble.fill" : "checkmark.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(choseNew ? Theme.Colors.brandRed : Theme.Colors.brandGreen)

            Text(choseNew ? "Starting a new chat…" : "Continuing this conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.md)
    }
}

private struct StaleChatActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
