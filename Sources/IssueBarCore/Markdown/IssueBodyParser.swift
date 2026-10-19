import Foundation

/// Splits an issue body into the blocks the detail pane can show: enough
/// Markdown for issues written by people and agents, not a full CommonMark parser.
///
/// Images uploaded through the GitHub website are only reachable through
/// short-lived signed URLs in private repositories; those come from the
/// rendered `html` and replace the Markdown URLs in the same order.
public struct IssueBodyParser: Sendable {
    public init() {}

    public func parse(markdown: String, html: String? = nil) -> [IssueBodyBlock] {
        let blocks = parseBlocks(markdown)
        return substituteSignedImages(in: blocks, html: html)
    }

    // MARK: Blocks

    private func parseBlocks(_ markdown: String) -> [IssueBodyBlock] {
        var blocks: [IssueBodyBlock] = []
        var paragraph: [String] = []
        var code: [String]?

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            paragraph = []
        }

        for rawLine in markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if let lines = code {
                    blocks.append(.code(lines.joined(separator: "\n")))
                    code = nil
                } else {
                    flushParagraph()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
            } else if let heading = Self.heading(line) {
                flushParagraph()
                blocks.append(heading)
            } else if Self.isRule(line) {
                flushParagraph()
                blocks.append(.rule)
            } else if line.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(line.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else if let item = Self.listItem(line) {
                flushParagraph()
                blocks.append(contentsOf: splitImages(item.text).map { piece in
                    if case .paragraph(let text) = piece { .listItem(marker: item.marker, text: text) } else { piece }
                })
            } else if Self.containsImage(line) {
                flushParagraph()
                blocks.append(contentsOf: splitImages(line))
            } else {
                paragraph.append(line)
            }
        }
        if let code { blocks.append(.code(code.joined(separator: "\n"))) }
        flushParagraph()
        return blocks
    }

    private static func heading(_ line: String) -> IssueBodyBlock? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return .heading(level: hashes, text: String(line.dropFirst(hashes + 1)))
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.filter { $0 != " " }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func listItem(_ line: String) -> (marker: String, text: String)? {
        for bullet in ["- [ ] ", "- [x] ", "- ", "* ", "+ "] where line.hasPrefix(bullet) {
            let marker = bullet == "- [ ] " ? "☐" : bullet == "- [x] " ? "☑" : "•"
            return (marker, String(line.dropFirst(bullet.count)))
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, line.dropFirst(digits.count).hasPrefix(". ") {
            return ("\(digits).", String(line.dropFirst(digits.count + 2)))
        }
        return nil
    }

    // MARK: Images

    private static let imagePattern = try! NSRegularExpression(
        pattern: #"!\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)|<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["'][^>]*>"#,
        options: [.caseInsensitive]
    )

    private static func containsImage(_ line: String) -> Bool {
        imagePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    /// Text around images becomes paragraphs, so an inline image still gets its own row.
    private func splitImages(_ line: String) -> [IssueBodyBlock] {
        var blocks: [IssueBodyBlock] = []
        var cursor = line.startIndex
        for match in Self.imagePattern.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            guard let range = Range(match.range, in: line) else { continue }
            appendText(line[cursor..<range.lowerBound], to: &blocks)
            let urlRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            if let urlText = Range(urlRange, in: line).map({ String(line[$0]) }),
               let url = URL(string: urlText.replacingOccurrences(of: "&amp;", with: "&")) {
                blocks.append(.image(url))
            }
            cursor = range.upperBound
        }
        appendText(line[cursor...], to: &blocks)
        return blocks
    }

    private func appendText(_ text: Substring, to blocks: inout [IssueBodyBlock]) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { blocks.append(.paragraph(trimmed)) }
    }

    private func substituteSignedImages(in blocks: [IssueBodyBlock], html: String?) -> [IssueBodyBlock] {
        guard let html else { return blocks }
        let sources = Self.imagePattern
            .matches(in: html, range: NSRange(html.startIndex..., in: html))
            .compactMap { match -> URL? in
                guard let range = Range(match.range(at: 2), in: html) else { return nil }
                return URL(string: String(html[range]).replacingOccurrences(of: "&amp;", with: "&"))
            }
        let imageCount = blocks.filter { if case .image = $0 { true } else { false } }.count
        guard sources.count == imageCount else { return blocks }

        var signed = sources.makeIterator()
        return blocks.map { block in
            guard case .image(let url) = block, let source = signed.next() else { return block }
            return Self.isWebUpload(url) ? .image(source) : block
        }
    }

    private static func isWebUpload(_ url: URL) -> Bool {
        url.host == "github.com" && url.path.hasPrefix("/user-attachments/")
    }
}
