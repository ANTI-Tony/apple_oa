import AppKit
import Foundation
import Observation
import ReportCore
import SwiftUI

/// Preview width presets. Email clients wrap around 600 points; chat tools
/// show narrower cards.
enum PreviewWidth: String, CaseIterable, Identifiable {
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
        case .chat: "Chat · 480"
        case .email: "Email · 600"
        case .wide: "Wide · 800"
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

/// UI state that is not part of the document: report visibility, preview
/// width, transient notices, and the copy/export actions that produce them.
@MainActor
@Observable
final class WorkspaceState {
    /// Whether the accessibility report popover is open.
    var showAccessibilityReport = false
    var previewWidth: PreviewWidth = .email
    var highlightedBlockID: UUID?
    private(set) var notice: Notice?

    private var noticeTask: Task<Void, Never>?
    private var highlightTask: Task<Void, Never>?

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

    /// Scrolls the editor to a block and outlines it briefly. Used by the
    /// accessibility inspector to jump to an issue.
    func highlight(blockID: UUID) {
        highlightedBlockID = blockID
        highlightTask?.cancel()
        highlightTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if self?.highlightedBlockID == blockID {
                self?.highlightedBlockID = nil
            }
        }
    }

    // MARK: Copy and export

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
