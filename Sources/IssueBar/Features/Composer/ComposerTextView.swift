import AppKit
import UniformTypeIdentifiers
import IssueBarCore

/// Keeps the encoded image next to its on-screen preview.
final class ImageAttachment: NSTextAttachment {
    static let maxPreviewSize = NSSize(width: 560, height: 180)

    let draftImage: DraftImage

    init(draftImage: DraftImage, image: NSImage, maxWidth: CGFloat) {
        self.draftImage = draftImage
        super.init(data: nil, ofType: nil)
        self.image = image
        let limit = NSSize(width: min(maxWidth, Self.maxPreviewSize.width), height: Self.maxPreviewSize.height)
        let scale = min(1, limit.width / max(image.size.width, 1), limit.height / max(image.size.height, 1))
        bounds = CGRect(x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale)
    }

    required init?(coder: NSCoder) { nil }
}

/// Plain-text editor that accepts pasted images inline, each on its own line.
final class ComposerTextView: NSTextView {
    static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 16),
        .foregroundColor: NSColor.labelColor,
    ]

    var pasteboard: NSPasteboard = .general

    /// The editor is plain text: typing next to an image would otherwise inherit
    /// the attachment character's attributes and fall back to black Helvetica.
    override var typingAttributes: [NSAttributedString.Key: Any] {
        get { super.typingAttributes }
        set { super.typingAttributes = newValue.merging(Self.textAttributes) { _, composer in composer } }
    }

    static func attachmentString(_ attachment: ImageAttachment) -> NSAttributedString {
        let string = NSMutableAttributedString(attachment: attachment)
        string.addAttributes(textAttributes, range: NSRange(location: 0, length: string.length))
        return string
    }

    static func configured(size: NSSize) -> ComposerTextView {
        let textView = ComposerTextView(frame: NSRect(origin: .zero, size: size))
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 15, height: 14)
        textView.typingAttributes = textAttributes
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        return textView
    }

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] { [.string] }

    /// SwiftUI may hand first responder back to the hosting view when the search
    /// field disappears, so the editor claims it once it lands in a window.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    /// NSTextView only enables Paste for formats it imports itself, which
    /// excludes bare images while `importsGraphics` is off; ⌘V would just beep.
    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard item.action == #selector(paste(_:)) else { return super.validateUserInterfaceItem(item) }
        return isEditable && (pasteboard.string(forType: .string) != nil || !PasteboardImages.read(from: pasteboard).isEmpty)
    }

    override func paste(_ sender: Any?) {
        let images = PasteboardImages.read(from: pasteboard)
        guard !images.isEmpty else {
            pasteText()
            return
        }
        insertImages(images)
    }

    /// `pasteAsPlainText` always reads the general pasteboard, so the text is inserted by hand.
    private func pasteText() {
        guard let text = pasteboard.string(forType: .string) else {
            NSSound.beep()
            return
        }
        replaceSelection(with: NSAttributedString(string: text, attributes: Self.textAttributes))
    }

    var previewWidth: CGFloat {
        guard let container = textContainer, container.size.width > 100 else { return ImageAttachment.maxPreviewSize.width }
        return container.size.width - container.lineFragmentPadding * 2
    }

    private func insertImages(_ images: [NSImage]) {
        let insertion = NSMutableAttributedString()
        let location = selectedRange().location
        let text = string as NSString
        if location > 0, text.character(at: location - 1) != 0x0A {
            insertion.append(Self.lineBreak)
        }
        for image in images {
            guard let draftImage = ImageEncoder.draftImage(from: image) else { continue }
            let attachment = ImageAttachment(draftImage: draftImage, image: image, maxWidth: previewWidth)
            insertion.append(Self.attachmentString(attachment))
            insertion.append(Self.lineBreak)
        }
        replaceSelection(with: insertion)
    }

    /// `insertText` drops attachments while `importsGraphics` is off, which is
    /// what keeps arbitrary drops and rich pastes out, so attachments go in directly.
    private func replaceSelection(with insertion: NSAttributedString) {
        let range = selectedRange()
        guard let textStorage, shouldChangeText(in: range, replacementString: insertion.string) else { return }
        textStorage.replaceCharacters(in: range, with: insertion)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + insertion.length, length: 0))
        typingAttributes = Self.textAttributes
        scrollRangeToVisible(selectedRange())
    }

    private static var lineBreak: NSAttributedString {
        NSAttributedString(string: "\n", attributes: textAttributes)
    }
}

/// Image files copied in Finder win; otherwise any text wins over image data,
/// so copying formatted text that carries a preview image still pastes text.
enum PasteboardImages {
    static func read(from pasteboard: NSPasteboard) -> [NSImage] {
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL], !files.isEmpty {
            return files.compactMap(NSImage.init(contentsOf:))
        }
        guard pasteboard.string(forType: .string) == nil else { return [] }
        return pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] ?? []
    }
}
