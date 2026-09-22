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
    @State private var help = HelpState()

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(help)
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
            HelpCommands(help: help)
        }

        // The usage guide, in the corner macOS keeps help in (ADR 0013).
        // `Window` rather than `WindowGroup`: a second ⌘? raises the one that is
        // open instead of stacking duplicates, and it joins the Window menu.
        Window("Reporting Builder Help", id: HelpState.windowID) {
            HelpWindow()
                .environment(help)
                .environment(workspace)
                .frame(minWidth: 620, idealWidth: 760, minHeight: 420, idealHeight: 580)
        }
        .defaultSize(width: 760, height: 580)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(preferences)
                .environment(assistant)
        }
    }
}
