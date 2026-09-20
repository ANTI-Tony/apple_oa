import CoreTransferable
import Foundation
import ReportCore
import UniformTypeIdentifiers

/// Makes a card shareable through the system share sheet and draggable into
/// other apps. Representations are produced lazily, so building this value
/// is free until a receiver asks for data.
struct CardTransfer: Transferable, Sendable {
    let card: SnippetCard
    var width: CGFloat = 600

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { transfer in
            let data = try await transfer.pngData()
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(transfer.card.title.fileNameSafe)-\(UUID().uuidString.prefix(6)).png")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        DataRepresentation(exportedContentType: .png) { transfer in
            try await transfer.pngData()
        }
        DataRepresentation(exportedContentType: .html) { transfer in
            Data(HTMLRenderer(options: .standalone).render(transfer.card).utf8)
        }
        DataRepresentation(exportedContentType: .utf8PlainText) { transfer in
            Data(PlainTextRenderer().render(transfer.card).utf8)
        }
    }

    private func pngData() async throws -> Data {
        let card = card
        let width = width
        let data = await MainActor.run { CardExporter.pngData(for: card, width: width) }
        guard let data else { throw ExportError.renderFailed }
        return data
    }
}
