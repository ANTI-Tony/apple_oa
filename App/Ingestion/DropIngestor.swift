import AppKit
import ReportCore
import UniformTypeIdentifiers

/// Turns dropped files, images and text into blocks.
@MainActor
enum DropIngestor {
    static let supportedTypes: [UTType] = [
        .fileURL, .image, .plainText, .utf8PlainText, .commaSeparatedText, .tabSeparatedText, .json,
    ]

    static func blocks(from providers: [NSItemProvider]) async -> [Block] {
        var result: [Block] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                if let url = await loadFileURL(provider), let block = block(fromFile: url) {
                    result.append(block)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let data = await loadData(provider, type: .image),
                   let image = ImageImport.imageBlock(from: data, fileName: "Dropped image") {
                    result.append(.image(image))
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await loadText(provider) {
                    result.append(contentsOf: blocks(fromText: text))
                }
            }
        }
        return result
    }

    static func block(fromFile url: URL) -> Block? {
        let ext = url.pathExtension.lowercased()
        if TextFileImport.imageExtensions.contains(ext) {
            return ImageImport.imageBlock(from: url).map(Block.image)
        }
        if TextFileImport.textExtensions.contains(ext), let text = TextFileImport.read(url) {
            return blocks(fromText: text).first
        }
        return nil
    }

    static func blocks(fromText text: String) -> [Block] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        switch ContentDetector.detect(trimmed) {
        case let .metrics(result):
            return [.metrics(MetricsBlock(metrics: result.metrics))]
        case let .text(text):
            return [.text(TextBlock(body: text))]
        }
    }

    // MARK: Item provider loading

    private static func loadFileURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                continuation.resume(returning: url)
            }
        }
    }

    private static func loadData(_ provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let text = (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
                continuation.resume(returning: text)
            }
        }
    }
}
