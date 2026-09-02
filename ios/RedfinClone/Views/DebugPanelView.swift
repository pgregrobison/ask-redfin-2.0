import SwiftUI

struct DebugPanelView: View {
    @Bindable var settings: DebugSettings
    var onPlaySplash: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(GlobalEntrypoint.allCases, id: \.self) { option in
                        Button {
                            settings.globalEntrypoint = option
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.rawValue)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.globalEntrypoint == option {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Global Entrypoint")
                } footer: {
                    Text("Controls how Ask Redfin is surfaced across the app. Accessory requires iOS 26.")
                }

                Section {
                    ForEach(SearchBehavior.allCases, id: \.self) { behavior in
                        Button {
                            settings.searchBehavior = behavior
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(behavior.rawValue)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(behavior.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.searchBehavior == behavior {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Search Behavior")
                } footer: {
                    Text("Controls how chat interacts with the map when searching for homes.")
                }

                Section {
                    Button("Play Intro Animation") {
                        dismiss()
                        onPlaySplash()
                    }
                    .foregroundStyle(Theme.Colors.brandRed)
                } header: {
                    Text("Launch Experience")
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

extension SearchBehavior {
    var subtitle: String {
        switch self {
        case .default: "Full sheet chat, manual show on map"
        case .mapFocus: "Chat drops to half-sheet on search, pins auto-fit"
        }
    }
}

extension GlobalEntrypoint {
    var subtitle: String {
        switch self {
        case .appNav: "Custom tab bar with Ask Redfin FAB"
        case .accessory: "Native tab bar with Ask Redfin input accessory (iOS 26)"
        }
    }
}
