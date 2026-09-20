import ReportCore
import SwiftUI

/// Entry point. Owns the three long-lived objects (card store, workspace
/// state, user preferences) and injects them into the environment.
@main
struct ReportingBuilderApp: App {
    @State private var store = CardStore.shared
    @State private var workspace = WorkspaceState()
    @State private var preferences = UserPreferences.shared
    @State private var assistant = AssistantSettings.shared

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(store)
                .environment(workspace)
                .environment(preferences)
                .environment(assistant)
                .frame(minWidth: WindowLayout.minimumWindowWidth, minHeight: 520)
        }
        .defaultSize(width: 1500, height: 900)
        .commands {
            CardCommands(store: store, workspace: workspace, preferences: preferences)
            // File ▸ Import from iPhone or iPad: take a photo of a whiteboard and
            // it lands on the card (Continuity Camera).
            ImportFromDevicesCommands()
        }

        Settings {
            SettingsView()
                .environment(preferences)
                .environment(assistant)
        }
    }
}
