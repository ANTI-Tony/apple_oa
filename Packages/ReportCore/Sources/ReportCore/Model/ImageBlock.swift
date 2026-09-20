import Foundation

/// Pixel dimensions of an image, used for `width`/`height` attributes so
/// exported HTML does not shift layout while images load.
public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Image encodings the card model accepts.
public enum ImageContentType: String, Codable, CaseIterable, Sendable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case gif = "image/gif"

    public var mimeType: String {
        rawValue
    }

    public var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .gif: "gif"
        }
    }

    /// Sniffs the encoding from magic bytes. Returns nil for unknown data.
    public static func detect(from data: Data) -> ImageContentType? {
        guard data.count >= 4 else { return nil }
        let bytes = [UInt8](data.prefix(4))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if bytes.starts(with: [0x47, 0x49, 0x46]) {
            return .gif
        }
        return nil
    }
}

/// An image asset with the text alternative accessibility requires.
public struct ImageBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var imageData: Data
    public var contentType: ImageContentType
    /// Text alternative for the image (WCAG 1.1.1). Required unless the image
    /// is marked decorative.
    public var altText: String
    /// Optional visible caption rendered below the image.
    public var caption: String
    /// True when the image carries no information (purely visual). Rendered
    /// with an empty `alt` so screen readers skip it.
    public var isDecorative: Bool
    public var pixelSize: PixelSize?
    /// Original file name, kept for export bookkeeping.
    public var fileName: String?

    public init(
        id: UUID = UUID(),
        imageData: Data,
        contentType: ImageContentType,
        altText: String = "",
        caption: String = "",
        isDecorative: Bool = false,
        pixelSize: PixelSize? = nil,
        fileName: String? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.contentType = contentType
        self.altText = altText
        self.caption = caption
        self.isDecorative = isDecorative
        self.pixelSize = pixelSize
        self.fileName = fileName
    }

    public var hasAcceptableAltText: Bool {
        isDecorative || !altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `data:` URI suitable for inline HTML.
    public var dataURI: String {
        "data:\(contentType.mimeType);base64,\(imageData.base64EncodedString())"
    }
}
