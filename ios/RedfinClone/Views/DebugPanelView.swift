import SwiftUI

struct DebugPanelView: View {
    @Bindable var settings: DebugSettings
    var onPlaySplash: () -> Void = {}
    var onPlayIntroQuery: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Type in the opening request", isOn: $settings.playIntroQuery)
                    Button("Replay opening request") {
                        dismiss()
                        onPlayIntroQuery()
                    }
                    Button("Play splash animation") {
                        dismiss()
                        onPlaySplash()
                    }
                } header: {
                    Text("Intro")
                } footer: {
                    Text("On launch, “Homes in Seattle under $1.3M…” types itself into the Ask bar and sends. Off: the app opens with that search already applied.")
                }

                Section {
                    Toggle("Launch Demo", isOn: $settings.launchDemoEnabled)
                } footer: {
                    Text("Adds the demo secret-room listing for recordings. Takes effect next launch.")
                }

                Section {
                    Picker("Global entrypoint", selection: $settings.globalEntrypoint) {
                        ForEach(GlobalEntrypoint.allCases, id: \.self) { option in
                            row(option.rawValue, option.subtitle).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Global Entrypoint")
                } footer: {
                    Text("Where the Ask bar lives. Accessory requires iOS 26.")
                }

                Section {
                    Picker("Find top chrome", selection: $settings.findChromeStyle) {
                        ForEach(FindChromeStyle.allCases, id: \.self) { style in
                            row(style.rawValue, style.subtitle).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Find Top Chrome")
                }
            }
            .font(Nova.Typography.body16)
            .tint(Nova.Color.brandFixed)
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Nova.Typography.body16)
            Text(subtitle).font(Nova.Typography.label14).foregroundStyle(.secondary)
        }
    }
}

extension GlobalEntrypoint {
    var subtitle: String {
        switch self {
        case .appNav: "Ask bar above the tab bar"
        case .accessory: "Ask bar in the tab bar accessory (iOS 26)"
        }
    }
}

extension FindChromeStyle {
    var subtitle: String {
        switch self {
        case .classic: "Filter pills + Ask bar"
        case .searchBar: "Search bar with an inline Ask button"
        }
    }
}
