import AppKit
import SwiftUI
import IssueBarCore

/// Bridges `ComposerTextView` into SwiftUI. The text view owns the content while
/// editing and reports it as segments; the view model only pushes content back
/// in on reset (`resetToken`) or when the view is recreated.
struct RichComposer: NSViewRepresentable {
    let segments: [DraftSegment]
    let resetToken: Int
    let focusToken: Int
    let isEditable: Bool
    let onChange: ([DraftSegment]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = ComposerTextView.configured(size: scrollView.contentSize)
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.load(segments)
        context.coordinator.lastResetToken = resetToken
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onChange = onChange
        coordinator.textView?.isEditable = isEditable

        if resetToken != coordinator.lastResetToken {
            coordinator.lastResetToken = resetToken
            coordinator.load(segments)
        }
        if focusToken != coordinator.lastFocusToken {
            coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                guard let textView = coordinator.textView else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: ([DraftSegment]) -> Void
        weak var textView: ComposerTextView?
        var lastResetToken = 0
        var lastFocusToken = Int.min

        init(onChange: @escaping ([DraftSegment]) -> Void) {
            self.onChange = onChange
        }

        func textDidChange(_ notification: Notification) {
            guard let storage = textView?.textStorage else { return }
            onChange(Self.segments(from: storage))
        }

        func load(_ segments: [DraftSegment]) {
            guard let textView else { return }
            textView.textStorage?.setAttributedString(Self.attributedString(from: segments, previewWidth: textView.previewWidth))
            textView.typingAttributes = ComposerTextView.textAttributes
        }

        static func segments(from storage: NSAttributedString) -> [DraftSegment] {
            var segments: [DraftSegment] = []
            storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                if let attachment = value as? ImageAttachment {
                    segments.append(.image(attachment.draftImage))
                } else if value == nil {
                    segments.append(.text(storage.attributedSubstring(from: range).string))
                }
            }
            return DraftDocument(segments: segments).segments
        }

        static func attributedString(from segments: [DraftSegment], previewWidth: CGFloat) -> NSAttributedString {
            let result = NSMutableAttributedString()
            for segment in segments {
                switch segment {
                case .text(let text):
                    result.append(NSAttributedString(string: text, attributes: ComposerTextView.textAttributes))
                case .image(let draftImage):
                    guard let image = NSImage(data: draftImage.data) else { continue }
                    let attachment = ImageAttachment(draftImage: draftImage, image: image, maxWidth: previewWidth)
                    result.append(ComposerTextView.attachmentString(attachment))
                }
            }
            return result
        }
    }
}
