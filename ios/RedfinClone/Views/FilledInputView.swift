import SwiftUI

struct FilledInputView: View {
    let label: String
    let value: String
    var icon: String = "pencil"

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.inter(15, .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.medium, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 68)
        .background(Theme.Colors.inset, in: .rect(cornerRadius: Theme.Radius.medium))
    }
}
