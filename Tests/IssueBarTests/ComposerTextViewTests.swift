import AppKit
import Testing
@testable import IssueBar
import IssueBarCore

/// Runs entirely off-screen on a private pasteboard: no window, focus or system clipboard involved.
@MainActor
struct ComposerTextViewTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("IssueBarTests.\(UUID().uuidString)"))
    private let textView = ComposerTextView.configured(size: NSSize(width: 640, height: 300))
    /// Never ordered on screen; it only supplies the undo manager a real window would.
    private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 300), styleMask: [.borderless], backing: .buffered, defer: true)

    init() {
        textView.pasteboard = pasteboard
        window.contentView = textView
    }

    private func paste(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        textView.paste(nil)
    }

    private func paste(image: NSImage) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        textView.paste(nil)
    }

    private var segments: [DraftSegment] {
        RichComposer.Coordinator.segments(from: textView.textStorage!)
    }

    @Test func textAndImagesInterleaveInPasteOrder() throws {
        paste(text: "Падает импорт\nВот что вижу:")
        paste(image: .sample(color: .systemRed))
        paste(text: "А после перезапуска так:")
        paste(image: .sample(color: .systemBlue))
        paste(text: "Конец")

        let shape = segments.map { segment -> String in
            switch segment {
            case .text(let text): "text(\(text))"
            case .image(let image): "image(\(image.fileExtension))"
            }
        }
        #expect(shape == [
            "text(Падает импорт\nВот что вижу:\n)",
            "image(png)",
            "text(\nА после перезапуска так:\n)",
            "image(png)",
            "text(\nКонец)",
        ])

        let draft = try #require(DraftDocument(segments: segments).makeDraft(imageURLs: [
            URL(string: "https://img.test/1.png")!, URL(string: "https://img.test/2.png")!,
        ]))
        #expect(draft.title == "Падает импорт")
        #expect(draft.body == "Вот что вижу:\n![image](https://img.test/1.png)\nА после перезапуска так:\n![image](https://img.test/2.png)\nКонец")
    }

    /// ⌘V goes through the Edit menu, which first asks the editor whether Paste is enabled.
    @Test func pasteMenuItemIsEnabledForImageOnlyPasteboard() throws {
        let pasteItem = try #require(MainMenu.make().items.first?.submenu?.items.first { $0.action == #selector(NSText.paste(_:)) })
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage.sample(color: .systemRed)])
        #expect(textView.validateMenuItem(pasteItem))

        pasteboard.clearContents()
        pasteboard.setString("текст", forType: .string)
        #expect(textView.validateMenuItem(pasteItem))

        pasteboard.clearContents()
        #expect(!textView.validateMenuItem(pasteItem))
    }

    private func type(_ text: String) {
        textView.insertText(text, replacementRange: textView.selectedRange())
    }

    private func expectComposerStyle(at location: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        let attributes = textView.textStorage!.attributes(at: location, effectiveRange: nil)
        #expect((attributes[.font] as? NSFont) == ComposerTextView.textAttributes[.font] as? NSFont, sourceLocation: sourceLocation)
        #expect((attributes[.foregroundColor] as? NSColor) == NSColor.labelColor, sourceLocation: sourceLocation)
    }

    @Test(arguments: [
        "typed right after the paste",
        "typed after deleting the line break",
        "typed on a new line",
        "typed after clicking back after the image",
    ])
    func textAfterAnImageKeepsTheComposerStyle(_ scenario: String) {
        paste(image: .sample(color: .systemRed))
        switch scenario {
        case "typed after deleting the line break":
            textView.deleteBackward(nil)
        case "typed on a new line":
            textView.insertNewline(nil)
        case "typed after clicking back after the image":
            textView.setSelectedRange(NSRange(location: 1, length: 0))
        default:
            break
        }
        let start = textView.selectedRange().location
        type("Добавить")
        expectComposerStyle(at: start)
    }

    @Test func textTypedBeforeAnImageAtTheStartKeepsTheComposerStyle() {
        paste(image: .sample(color: .systemRed))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        type("Заголовок")
        expectComposerStyle(at: 0)
    }

    @Test func pastedImageDataDecodesBackToTheSameSize() throws {
        paste(image: .sample(color: .systemGreen, size: NSSize(width: 120, height: 80)))
        guard case .image(let draftImage) = try #require(segments.first) else {
            Issue.record("expected an image segment")
            return
        }
        let decoded = try #require(NSBitmapImageRep(data: draftImage.data))
        #expect(decoded.pixelsWide == 120)
        #expect(decoded.pixelsHigh == 80)
    }

    @Test func richTextIsPastedAsPlainText() {
        pasteboard.clearContents()
        let styled = NSAttributedString(string: "жирный", attributes: [.font: NSFont.boldSystemFont(ofSize: 40)])
        pasteboard.writeObjects([styled])
        textView.paste(nil)

        #expect(segments == [.text("жирный")])
        let font = textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 16)
    }

    @Test func textWinsWhenPasteboardAlsoCarriesAnImage() {
        pasteboard.clearContents()
        pasteboard.setString("подпись", forType: .string)
        pasteboard.setData(NSImage.sample(color: .systemRed).tiffRepresentation, forType: .tiff)
        textView.paste(nil)

        #expect(segments == [.text("подпись")])
    }

    @Test func imageFileCopiedInFinderIsPastedAsImage() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "IssueBarTests-\(UUID().uuidString).png")
        let png = try #require(NSBitmapImageRep(data: NSImage.sample(color: .systemOrange).tiffRepresentation!)?
            .representation(using: .png, properties: [:]))
        try png.write(to: file)
        pasteboard.clearContents()
        pasteboard.writeObjects([file as NSURL])
        textView.paste(nil)

        guard case .image = segments.first else {
            Issue.record("expected an image segment, got \(segments)")
            return
        }
        #expect(segments.dropFirst() == [.text("\n")])
    }

    @Test func imageInTheMiddleOfALineGetsItsOwnLine() {
        paste(text: "до")
        paste(image: .sample(color: .systemRed))

        #expect(segments.first == .text("до\n"))
    }

    @Test func undoRemovesThePastedImage() throws {
        paste(image: .sample(color: .systemRed))
        let undoManager = try #require(textView.undoManager)
        #expect(undoManager.canUndo)
        undoManager.undo()

        #expect(segments.isEmpty)
    }

    @Test func loadedSegmentsRoundTrip() {
        let image = ImageEncoder.draftImage(from: .sample(color: .systemPurple))!
        let original: [DraftSegment] = [.text("a\n"), .image(image), .text("\nb")]
        textView.textStorage?.setAttributedString(
            RichComposer.Coordinator.attributedString(from: original, previewWidth: textView.previewWidth)
        )
        #expect(segments == original)
    }
}

extension NSImage {
    /// A bitmap with exact pixel dimensions, like a pasted screenshot.
    static func sample(color: NSColor, size: NSSize = NSSize(width: 40, height: 30)) -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
