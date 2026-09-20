import AppKit
import ReportCore

/// Normalises incoming images into the encodings the card model accepts.
@MainActor
enum ImageImport {
    /// Images wider than this are downscaled so cards stay small enough to
    /// paste into email.
    static let maxPixelWidth = 1600

    static func imageBlock(from url: URL) -> ImageBlock? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return imageBlock(from: data, fileName: url.lastPathComponent)
    }

    static func imageBlock(from data: Data, fileName: String? = nil) -> ImageBlock? {
        guard let normalised = normalise(data) else { return nil }
        return ImageBlock(
            imageData: normalised.data,
            contentType: normalised.type,
            altText: "",
            pixelSize: normalised.size,
            fileName: fileName
        )
    }

    /// Keeps PNG/JPEG/GIF as-is when small enough; otherwise re-encodes as PNG,
    /// downscaling to `maxPixelWidth`. TIFF, HEIC and other formats always
    /// become PNG.
    static func normalise(_ data: Data) -> (data: Data, type: ImageContentType, size: PixelSize)? {
        guard let rep = NSBitmapImageRep(data: data) ?? NSImage(data: data)?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)) else {
            return nil
        }
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        if let type = ImageContentType.detect(from: data), width <= maxPixelWidth {
            return (data, type, PixelSize(width: width, height: height))
        }
        let scale = min(1, CGFloat(maxPixelWidth) / CGFloat(max(width, 1)))
        let targetWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        guard let cgImage = rep.cgImage,
              let context = CGContext(
                  data: nil,
                  width: targetWidth,
                  height: targetHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: scaled).representation(using: .png, properties: [:]) else {
            return nil
        }
        return (png, .png, PixelSize(width: targetWidth, height: targetHeight))
    }

    static func pixelSize(of data: Data) -> PixelSize? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return PixelSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}

/// Reads text files chosen by the user, honouring sandbox scoping.
enum TextFileImport {
    static func read(_ url: URL) -> String? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "tif", "bmp", "webp"]
    static let textExtensions: Set<String> = ["csv", "tsv", "txt", "text", "json", "md", "markdown"]
}
