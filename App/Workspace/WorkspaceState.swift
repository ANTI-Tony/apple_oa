import AppKit
import Foundation
import Observation
import ReportCore
import SwiftUI

/// Export widths. Email clients wrap around 600 points; chat tools show
/// narrower cards. The canvas uses the same width so it previews the export.
enum CardWidth: String, CaseIterable, Identifiable {
    case chat, email, wide

    var id: String {
        rawValue
    }

    var points: CGFloat {
        switch self {
        case .chat: 480
        case .email: 600
        case .wide: 800
        }
    }

    var label: String {
        switch self {
        case .chat: "Chat (480)"
        case .email: "Email (600)"
        case .wide: "Wide (800)"
        }
    }
}

/// A transient confirmation shown at the bottom of the window and announced
/// to VoiceOver.
struct Notice: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var isError: Bool
}

/// UI state that is not part of the document: selection, the inspector, the
/// export width, transient notices, and the copy/export actions.
@MainActor
@Observable
final class WorkspaceState {
    /// The block being formatted. Set by putting the caret in a block or
    /// clicking it, cleared by clicking the desk around the card.
    var selectedBlockID: UUID?
    /// Whether the user wants the Format inspector. Narrow windows hide it
    /// without forgetting this.
    var wantsInspector = true
    var inspectorTab: InspectorTab = LaunchOverrides.inspectorTab ?? .card
    var cardWidth: CardWidth = .email

    /// One-shot requests from the toolbar and menus to the canvas.
    var insertRequest: InsertRequest?
    var scrollTarget: UUID?
    var isImportingImage = false
    var pendingPaste: PastePayload?

    private(set) var notice: Notice?
    private var noticeTask: Task<Void, Never>?

    /// Opens the inspector on a tab, e.g. from "Add Description" on an image.
    func reveal(_ tab: InspectorTab) {
        inspectorTab = tab
        wantsInspector = true
    }

    // MARK: Notices

    func announce(_ text: String, isError: Bool = false) {
        notice = Notice(text: text, isError: isError)
        AccessibilityNotification.Announcement(text).post()
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(isError ? 4 : 2.5))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    // MARK: Copy and export

    func exportPreferences(from preferences: UserPreferences) -> ExportPreferences {
        ExportPreferences(scale: preferences.exportScale, includeFooter: preferences.includeFooter, width: cardWidth.points)
    }

    func copy(_ card: SnippetCard, variant: CopyVariant, preferences: ExportPreferences) {
        do {
            try PasteboardWriter.copy(card, variant: variant, preferences: preferences)
            announce(variant.confirmation)
        } catch {
            announce("Copy failed: \(error.localizedDescription)", isError: true)
        }
    }

    func export(_ card: SnippetCard, format: ExportFormat, preferences: ExportPreferences) {
        let suggested = CardExporter.suggestedFileName(for: card, format: format)
        guard let url = FilePanels.pickSaveURL(suggestedName: suggested, contentType: format.contentType) else { return }
        do {
            try CardExporter.write(card, format: format, to: url, preferences: preferences)
            announce("Exported \(url.lastPathComponent)")
        } catch {
            announce("Export failed: \(error.localizedDescription)", isError: true)
        }
    }
}
