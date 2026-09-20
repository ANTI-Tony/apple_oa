import ReportCore
import SwiftUI

struct SettingsView: View {
    @Environment(UserPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
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
}
