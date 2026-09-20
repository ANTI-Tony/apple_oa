import ReportCore
import SwiftUI

/// Entry point. Owns the three long-lived objects (card store, workspace
/// state, user preferences) and injects them into the environment.
@main
struct ReportingBuilderApp: App {
    @State private var store = CardStore.shared
    @State private var workspace = WorkspaceState()
    @State private var preferences = UserPreferences.shared

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(store)
                .environment(workspace)
                .environment(preferences)
                .frame(minWidth: WindowLayout.minimumWindowWidth, minHeight: 520)
        }
        .defaultSize(width: 1500, height: 900)
        .commands {
            CardCommands(store: store, workspace: workspace, preferences: preferences)
        }

        Settings {
            SettingsView()
                .environment(preferences)
        }
    }
}
