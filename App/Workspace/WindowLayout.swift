import AppKit
import SwiftUI

/// How the main window arranges its panes at a given width. This is the app's
/// answer to "responsive": the same content reflows from three columns down to
/// a single pane instead of clipping or forcing a wide window.
enum WindowLayout: Equatable {
    /// Sidebar, editor and preview side by side.
    case wide
    /// Editor and preview; the sidebar collapses (the toolbar button brings it back).
    case medium
    /// One pane at a time, with an Edit/Preview switch in the toolbar.
    case compact

    /// Below this the sidebar is collapsed automatically.
    static let mediumBreakpoint: CGFloat = 1100
    /// Below this the editor and preview no longer fit side by side.
    static let compactBreakpoint: CGFloat = 760
    static let minimumWindowWidth: CGFloat = 560

    static func forWidth(_ width: CGFloat) -> WindowLayout {
        if width >= mediumBreakpoint {
            return .wide
        }
        if width >= compactBreakpoint {
            return .medium
        }
        return .compact
    }

    var columnVisibility: NavigationSplitViewVisibility {
        switch self {
        case .wide: .all
        case .medium: .doubleColumn
        case .compact: .detailOnly
        }
    }
}

/// Which pane the single-pane layout shows.
enum CompactPane: String, CaseIterable, Identifiable {
    case edit, preview

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .edit: "Edit"
        case .preview: "Preview"
        }
    }
}

/// Test-only launch overrides, honoured only together with `-uiTesting`.
enum LaunchOverrides {
    /// `-windowSize 700x640 -uiTesting` resizes the main window after launch so
    /// UI tests and screenshots can exercise each layout deterministically.
    ///
    /// Order matters: AppKit reads `-key value` pairs, so the valueless
    /// `-uiTesting` flag must come last. Put it first and it swallows
    /// `-windowSize` as its value, leaving `700x640` to be treated as a file to
    /// open, and the app launches without its window.
    static var windowSize: CGSize? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTesting"),
              let index = arguments.firstIndex(of: "-windowSize"), index + 1 < arguments.count else { return nil }
        let parts = arguments[index + 1].lowercased().split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
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
