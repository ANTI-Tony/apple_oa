import ReportCore
import SwiftUI

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @Environment(AssistantSettings.self) private var assistant
    @State private var apiKeyDraft = ""
    @State private var keyMessage: String?

    var body: some View {
        @Bindable var preferences = preferences
        @Bindable var assistant = assistant
        Form {
            Section("New cards") {
                Picker("Default template", selection: $preferences.defaultTemplateID) {
                    ForEach(CardTemplate.builtIn) { template in
                        Text(template.name).tag(template.id)
                    }
                }
                Picker("Default theme", selection: $preferences.defaultThemeID) {
                    ForEach(CardTheme.builtIn) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                TextField("Author name", text: $preferences.authorName, prompt: Text("Optional"))
                    .help("Shown in the footer of new cards, in every export format")
            }
            Section("Export") {
                Picker("PNG resolution", selection: $preferences.exportScale) {
                    Text("1× (standard)").tag(1)
                    Text("2× (Retina)").tag(2)
                    Text("3×").tag(3)
                }
                Toggle("Include “Updated” footer", isOn: $preferences.includeFooter)
            }
            if assistant.isAvailableInThisBuild {
                Section {
                    Toggle("Writing Assistance", isOn: $assistant.isEnabled)
                    if assistant.isEnabled {
                        Picker("Model", selection: $assistant.provider) {
                            ForEach(AssistantProvider.allCases) { provider in
                                Text(provider.label).tag(provider)
                            }
                        }
                        if assistant.provider == .onDevice {
                            if let reason = OnDeviceModel.unavailableReason {
                                Label("Not available on this Mac. \(reason)", systemImage: "exclamationmark.triangle")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("Nothing leaves this Mac.", systemImage: "lock.fill")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            TextField("Endpoint", text: $assistant.baseURLString, prompt: Text("https://…"))
                                .textContentType(.URL)
                            TextField("Model name", text: $assistant.model)
                            HStack {
                                SecureField(
                                    "API key",
                                    text: $apiKeyDraft,
                                    prompt: Text(assistant.hasAPIKey ? "Saved in Keychain" : "Paste a key")
                                )
                                Button(apiKeyDraft.isEmpty && assistant.hasAPIKey ? "Remove" : "Save") { saveKey() }
                                    .disabled(apiKeyDraft.isEmpty && !assistant.hasAPIKey)
                            }
                            if let keyMessage {
                                Text(keyMessage).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Writing Assistance")
                } footer: {
                    Text("""
                    Off by default. Used only when you choose New Card from Notes or a Refine button, and only for the text you give it. \
                    A custom endpoint receives that text over HTTPS; the key is kept in the Keychain. \
                    Images and your other cards are never sent. \
                    Do not send confidential information to a provider your organisation has not approved.
                    """)
                    .sectionFooterStyle()
                }
            }
            Section("About") {
                LabeledContent("Version", value: "\(AppConfiguration.version) (\(AppConfiguration.build))")
                LabeledContent("Build", value: AppConfiguration.buildFlavor)
                LabeledContent("Features", value: AppConfiguration.enabledFeatures.map(\.label).joined(separator: ", "))
                LabeledContent("Data file", value: AppPaths.cardsFile.path)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding(.vertical, 8)
    }

    private func saveKey() {
        do {
            try assistant.setAPIKey(apiKeyDraft)
            keyMessage = apiKeyDraft.isEmpty ? "Key removed from the Keychain." : "Key saved to the Keychain."
            apiKeyDraft = ""
        } catch {
            keyMessage = error.localizedDescription
        }
    }
}
