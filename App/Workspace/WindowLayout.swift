import AppKit
import SwiftUI

/// How the main window arranges itself at a given width. This is the app's
/// answer to "responsive": the same document reflows instead of clipping or
/// forcing a wide window.
enum WindowLayout: Equatable {
    /// Card list, canvas and Format inspector.
    case wide
    /// Canvas and inspector; the card list collapses (the toolbar button restores it).
    case medium
    /// Canvas only. The inspector is one click away in the toolbar.
    case compact

    /// Below this the card list is collapsed automatically.
    static let mediumBreakpoint: CGFloat = 1080
    /// Below this the inspector is hidden automatically.
    static let compactBreakpoint: CGFloat = 780
    static let minimumWindowWidth: CGFloat = 480

    static func forWidth(_ width: CGFloat) -> WindowLayout {
        if width >= mediumBreakpoint {
            return .wide
        }
        if width >= compactBreakpoint {
            return .medium
        }
        return .compact
    }

    var showsSidebar: Bool {
        self == .wide
    }

    var allowsInspector: Bool {
        self != .compact
    }

    var columnVisibility: NavigationSplitViewVisibility {
        showsSidebar ? .all : .detailOnly
    }
}

/// Test-only launch overrides, honoured only together with `-uiTesting`.
///
/// Order matters: AppKit reads `-key value` pairs, so the valueless
/// `-uiTesting` flag must come last. Put it first and it swallows the next key
/// as its value, leaving that key's value to be treated as a file to open, and
/// the app launches without its window.
enum LaunchOverrides {
    /// `-windowSize 700x640 -uiTesting` resizes the main window after launch so
    /// UI tests and screenshots can exercise each layout deterministically.
    static var windowSize: CGSize? {
        windowSize(in: ProcessInfo.processInfo.arguments)
    }

    /// `-inspectorTab accessibility -uiTesting` opens the inspector on a tab.
    static var inspectorTab: InspectorTab? {
        inspectorTab(in: ProcessInfo.processInfo.arguments)
    }

    /// `-visionSimulation deuteranopia -uiTesting` opens with a simulation on.
    static var visionSimulation: VisionSimulation? {
        value(for: "-visionSimulation", in: ProcessInfo.processInfo.arguments).flatMap(VisionSimulation.init(rawValue:))
    }

    /// `-stubAssistant YES -uiTesting` replaces the language model with a canned one.
    static var usesStubAssistant: Bool {
        value(for: "-stubAssistant", in: ProcessInfo.processInfo.arguments) == "YES"
    }

    /// `-demoDraft YES -uiTesting` opens New Card from Notes with the sample notes and generates.
    static var opensDraftDemo: Bool {
        value(for: "-demoDraft", in: ProcessInfo.processInfo.arguments) == "YES"
    }

    /// `-demoState missingDescription -uiTesting` seeds an image without a description.
    /// `largePrint` seeds an Extra Large card; `listening` seeds the undescribed image
    /// and starts Hear This Card muted.
    static var demoState: String? {
        value(for: "-demoState", in: ProcessInfo.processInfo.arguments)
    }

    /// `-demoHelp shortcuts -uiTesting` opens the help window at launch on a
    /// page. `YES` opens it on the page the menu item opens.
    static var helpTopic: String? {
        value(for: "-demoHelp", in: ProcessInfo.processInfo.arguments)
    }

    static var opensHelp: Bool {
        helpTopic != nil
    }

    static var seedsMissingDescription: Bool {
        demoState == "missingDescription" || demoState == "listening"
    }

    static var startsListeningMuted: Bool {
        demoState == "listening"
    }

    static func value(for key: String, in arguments: [String]) -> String? {
        guard arguments.contains("-uiTesting"),
              let index = arguments.firstIndex(of: key), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func windowSize(in arguments: [String]) -> CGSize? {
        guard let text = value(for: "-windowSize", in: arguments) else { return nil }
        let parts = text.lowercased().split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }

    static func inspectorTab(in arguments: [String]) -> InspectorTab? {
        value(for: "-inspectorTab", in: arguments).flatMap(InspectorTab.init(rawValue:))
    }

    @MainActor
    static func applyWindowSize() {
        guard let size = windowSize else { return }
        Task { @MainActor in
            // Applied a few times on purpose. A window cannot shrink below the
            // minimum of its current layout, so, like a user dragging the edge,
            // each pass gets as far as it can, the layout reflows, and the next
            // pass continues from there.
            for _ in 0 ..< 5 {
                try? await Task.sleep(for: .milliseconds(350))
                guard let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) else { continue }
                if abs(window.frame.width - size.width) < 1, abs(window.frame.height - size.height) < 1 {
                    break
                }
                var frame = window.frame
                frame.origin.y += frame.height - size.height
                frame.size = size
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }
}
