import SwiftUI

/// Which page the help window is showing. Held by the app and passed in
/// explicitly, the way `CardCommands` takes its stores.
@MainActor
@Observable
final class HelpState {
    static let windowID = "help"

    var topic: HelpTopic = .shortcuts
}

/// The Help menu.
///
/// macOS draws a Help menu whether or not an app fills it, and an app with no
/// help book gets one dead item that answers "Help isn't available". Replacing
/// the group is what turns that from a defect into the usual corner people look
/// in. See ADR 0013 for why this is a window rather than a help book.
struct HelpCommands: Commands {
    let help: HelpState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Reporting Builder Help") { open(.shortcuts) }
                .keyboardShortcut("?", modifiers: .command)

            Button("Accessibility Check") { open(.accessibility) }
            Button("Where Your Cards Live") { open(.storage) }

            Divider()

            Link("Card Gallery", destination: HelpLinks.gallery)
            Link("Source Repository", destination: HelpLinks.repository)
        }
    }

    private func open(_ topic: HelpTopic) {
        help.topic = topic
        openWindow(id: HelpState.windowID)
    }
}
