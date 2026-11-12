import SwiftUI

struct DebugPanelView: View {
    @Bindable var settings: DebugSettings
    var onPlaySplash: () -> Void = {}
    var onRestartScriptedFlow: () -> Void = {}
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
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(.primary)
                                    Text(option.subtitle)
                                        .font(Theme.Typography.caption)
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
                    ForEach(FindChromeStyle.allCases, id: \.self) { style in
                        Button {
                            settings.findChromeStyle = style
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.rawValue)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(.primary)
                                    Text(style.subtitle)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.findChromeStyle == style {
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
                    Text("Find Top Chrome")
                } footer: {
                    Text("Classic is the expanding location/filter pill with a separate Ask accessory bar. Search Bar is the newer single-row search + inline Ask button, which replaces the accessory bar.")
                }

                Section {
                    ForEach(SearchBehavior.allCases, id: \.self) { behavior in
                        Button {
                            settings.searchBehavior = behavior
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(behavior.rawValue)
                                        .font(Theme.Typography.body)
                                        .foregroundStyle(.primary)
                                    Text(behavior.subtitle)
                                        .font(Theme.Typography.caption)
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
                    Toggle("Launch Demo", isOn: $settings.launchDemoEnabled)
                    Button("Play Intro Animation") {
                        dismiss()
                        onPlaySplash()
                    }
                    .foregroundStyle(Theme.Colors.brandRed)
                    if DemoFixtures.isEnabled {
                        Button("Restart Scripted Demo") {
                            dismiss()
                            onRestartScriptedFlow()
                        }
                        .foregroundStyle(Theme.Colors.brandRed)
                    }
                } header: {
                    Text("Launch Experience")
                } footer: {
                    Text("Launch Demo opens Ask Redfin into a fixed scripted conversation for recording, instead of your normal chat history and listings. Off = Original, untouched behavior. Takes effect next launch. Restart Scripted Demo resets the seed thread and replays the autoplay sequence from the top, without relaunching the app.")
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
        case .appNav: "Custom tab bar"
        case .accessory: "Native tab bar with Ask Redfin input accessory (iOS 26)"
        }
    }
}

extension FindChromeStyle {
    var subtitle: String {
        switch self {
        case .classic: "Expanding location pill + bottom Ask accessory bar"
        case .searchBar: "Search bar with list/map toggle + inline Ask button"
        }
    }
}
