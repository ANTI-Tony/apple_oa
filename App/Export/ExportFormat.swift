import Foundation
import UniformTypeIdentifiers

/// File formats the app can write.
enum ExportFormat: String, CaseIterable, Identifiable {
    case png
    case html
    case markdown
    case plainText
    case json

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .png: "PNG Image"
        case .html: "HTML Page"
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .json: "JSON Card Data"
        }
    }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .html: "html"
        case .markdown: "md"
        case .plainText: "txt"
        case .json: "json"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .html: .html
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .plainText: .plainText
        case .json: .json
        }
    }
}

/// Options that affect rendered output.
struct ExportPreferences: Sendable {
    var scale: Int = 2
    var includeFooter: Bool = true
    /// Card width in points, for the PNG and the HTML max-width.
    var width: CGFloat = 600
}

enum ExportError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed: "The card could not be rendered as an image."
        }
    }
}
