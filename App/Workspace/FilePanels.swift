import AppKit
import UniformTypeIdentifiers

/// Thin wrappers over the AppKit open/save panels so views stay declarative.
@MainActor
enum FilePanels {
    static func pickSaveURL(suggestedName: String, contentType: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func pickOpenURLs(contentTypes: [UTType], allowsMultiple: Bool = false) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = contentTypes
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }
}
