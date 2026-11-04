import SwiftUI

struct GlassActionButton: View {
    let icon: String
    let action: () -> Void
    var foregroundColor: Color = .primary
    var size: CGFloat = Theme.IconSize.mediumTap

    /// `nova: true` draws a Nova icon (asset name) instead of an SF Symbol.
    var nova = false

    @ViewBuilder private var glyph: some View {
        if nova {
            NovaIcon(icon, size: 24)
        } else {
            Image(systemName: icon).font(.system(size: Theme.IconSize.medium, weight: .semibold))
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                glyph
                    .foregroundStyle(foregroundColor)
                    .frame(width: size, height: size)
                    .contentShape(Circle())
            }
            .fixedSize()
            .glassEffect(.regular.interactive(), in: .circle)
        } else {
            Button(action: action) {
                glyph
                    .foregroundStyle(foregroundColor)
                    .frame(width: size, height: size)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .fixedSize()
        }
    }
}

struct GlassActionMenuButton<MenuContent: View>: View {
    let icon: String
    @ViewBuilder let menuContent: () -> MenuContent
    var foregroundColor: Color = .primary

    /// `nova: true` draws a Nova icon (asset name) instead of an SF Symbol.
    var nova = false

    @ViewBuilder private var glyph: some View {
        if nova {
            NovaIcon(icon, size: 24)
        } else {
            Image(systemName: icon).font(.system(size: Theme.IconSize.medium, weight: .semibold))
        }
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Menu {
                menuContent()
            } label: {
                glyph
                    .foregroundStyle(foregroundColor)
                    .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                    .contentShape(Circle())
            }
            .glassEffect(in: .circle)
        } else {
            Menu {
                menuContent()
            } label: {
                glyph
                    .foregroundStyle(foregroundColor)
                    .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }
}

struct GlassActionButtonItem: Identifiable {
    let id = UUID()
    let icon: String
    let action: () -> Void
}

struct GlassActionButtonStack: View {
    let items: [GlassActionButtonItem]

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassActionButtonStackIOS26(items: items)
        } else {
            legacyStack
        }
    }

    private var legacyStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                        .contentShape(Rectangle())
                }
                if index < items.count - 1 {
                    Divider().frame(width: Theme.DividerSize.standard)
                }
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.full))
    }
}

@available(iOS 26.0, *)
private struct GlassActionButtonStackIOS26: View {
    let items: [GlassActionButtonItem]
    @Namespace private var unionNamespace

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(action: item.action) {
                        Image(systemName: item.icon)
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                            .contentShape(Rectangle())
                    }
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.full))
                    .glassEffectUnion(id: "stack", namespace: unionNamespace)
                    if index < items.count - 1 {
                        Divider().frame(width: Theme.DividerSize.standard)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct GlassActionButtonRow: View {
    let items: [GlassActionButtonItem]

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassActionButtonRowIOS26(items: items)
        } else {
            legacyRow
        }
    }

    private var legacyRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                        .contentShape(Rectangle())
                }
                if index < items.count - 1 {
                    Divider().frame(height: Theme.DividerSize.standard)
                }
            }
        }
        .background(.ultraThinMaterial, in: Capsule())
    }
}

@available(iOS 26.0, *)
private struct GlassActionButtonRowIOS26: View {
    let items: [GlassActionButtonItem]
    @Namespace private var unionNamespace

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button(action: item.action) {
                        Image(systemName: item.icon)
                            .font(.system(size: Theme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: Theme.IconSize.mediumTap, height: Theme.IconSize.mediumTap)
                            .contentShape(Rectangle())
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectUnion(id: "row", namespace: unionNamespace)
                    if index < items.count - 1 {
                        Divider().frame(height: Theme.DividerSize.standard)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
