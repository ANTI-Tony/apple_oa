import AppKit
import ReportCore

/// What the clipboard contained and how it should be inserted.
enum PastePayload: Identifiable {
    case image(ImageBlock)
    case metrics(MetricsParseResult, raw: String)
    case text(String)

    var id: String {
        switch self {
        case let .image(block): "image-\(block.id.uuidString)"
        case let .metrics(_, raw): "metrics-\(raw.hashValue)"
        case let .text(text): "text-\(text.hashValue)"
        }
    }
}

/// Reads the general pasteboard and classifies it: image, metric data or text.
@MainActor
enum PasteIngestor {
    static func read(from pasteboard: NSPasteboard = .general) -> PastePayload? {
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
           let block = ImageImport.imageBlock(from: data, fileName: "Pasted image") {
            return .image(block)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first {
            let ext = url.pathExtension.lowercased()
            if TextFileImport.imageExtensions.contains(ext), let block = ImageImport.imageBlock(from: url) {
                return .image(block)
            }
            if TextFileImport.textExtensions.contains(ext), let text = TextFileImport.read(url) {
                return classify(text)
            }
        }
        guard let string = pasteboard.string(forType: .string) else { return nil }
        return classify(string)
    }

    static func classify(_ string: String) -> PastePayload? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch ContentDetector.detect(trimmed) {
        case let .metrics(result): return .metrics(result, raw: trimmed)
        case let .text(text): return .text(text)
        }
    }
}
