import AppKit
import IssueBarCore

/// Screenshots stay lossless PNG; large photos fall back to JPEG to keep uploads small.
enum ImageEncoder {
    private static let pngSizeLimit = 4 * 1024 * 1024
    private static let jpegQuality = 0.85

    static func draftImage(from image: NSImage) -> DraftImage? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        if let png = bitmap.representation(using: .png, properties: [:]), png.count <= pngSizeLimit {
            return DraftImage(data: png, fileExtension: "png")
        }
        guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality]) else { return nil }
        return DraftImage(data: jpeg, fileExtension: "jpg")
    }
}
