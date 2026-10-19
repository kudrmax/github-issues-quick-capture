import Foundation

public struct DraftImage: Equatable, Sendable {
    public let data: Data
    public let fileExtension: String

    public init(data: Data, fileExtension: String) {
        self.data = data
        self.fileExtension = fileExtension
    }
}

public enum DraftSegment: Equatable, Sendable {
    case text(String)
    case image(DraftImage)
}

/// Issue content as written in the composer: text interleaved with images.
/// The first non-empty line of text becomes the title, everything else the body,
/// with images rendered as Markdown in their original positions.
public struct DraftDocument: Equatable, Sendable {
    public let segments: [DraftSegment]

    public init(segments: [DraftSegment]) {
        self.segments = Self.normalized(segments)
    }

    public init(text: String) {
        self.init(segments: [.text(text)])
    }

    public var isEmpty: Bool { segments.isEmpty }

    public var images: [DraftImage] {
        segments.compactMap { segment in
            if case .image(let image) = segment { image } else { nil }
        }
    }

    public var canBecomeIssue: Bool { titleLocation != nil }

    /// `imageURLs` must match `images` in order.
    public func makeDraft(imageURLs: [URL]) -> IssueDraft? {
        guard let location = titleLocation, imageURLs.count == images.count else { return nil }
        var urls = imageURLs.makeIterator()
        var body = ""
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .text(let text):
                body += index == location.segmentIndex ? location.remainder : text
            case .image:
                body += "![image](\(urls.next()!.absoluteString))"
            }
        }
        return IssueDraft(title: location.title, body: body.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var titleLocation: (segmentIndex: Int, title: String, remainder: String)? {
        for (index, segment) in segments.enumerated() {
            guard case .text(let text) = segment else { continue }
            var lines = text.components(separatedBy: .newlines)
            guard let lineIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                continue
            }
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            if line.count <= IssueDraft.maxTitleLength {
                lines.remove(at: lineIndex)
                return (index, line, lines.joined(separator: "\n"))
            }
            return (index, IssueDraft.shortened(line), text)
        }
        return nil
    }

    private static func normalized(_ segments: [DraftSegment]) -> [DraftSegment] {
        segments.reduce(into: []) { result, segment in
            switch (result.last, segment) {
            case (_, .text(let text)) where text.isEmpty:
                break
            case (.text(let previous)?, .text(let text)):
                result[result.count - 1] = .text(previous + text)
            default:
                result.append(segment)
            }
        }
    }
}
