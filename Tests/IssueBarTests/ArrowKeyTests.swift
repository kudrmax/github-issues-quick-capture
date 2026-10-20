import AppKit
import Testing
@testable import IssueBar

@MainActor
struct ArrowKeyTests {
    private func textView(_ text: String, selection: NSRange) -> NSTextView {
        let view = NSTextView()
        view.string = text
        view.setSelectedRange(selection)
        return view
    }

    @Test func arrowsSwitchScreensFromAnEmptyField() {
        let empty = textView("", selection: NSRange(location: 0, length: 0))
        #expect(KeyCommand.moveLeft.reachesBeyondText(in: empty))
        #expect(KeyCommand.moveRight.reachesBeyondText(in: empty))
    }

    @Test func leftArrowLeavesOnlyFromTheStartOfText() {
        #expect(KeyCommand.moveLeft.reachesBeyondText(in: textView("app", selection: NSRange(location: 0, length: 0))))
        #expect(!KeyCommand.moveLeft.reachesBeyondText(in: textView("app", selection: NSRange(location: 3, length: 0))))
    }

    @Test func rightArrowLeavesOnlyFromTheEndOfText() {
        #expect(KeyCommand.moveRight.reachesBeyondText(in: textView("приложение", selection: NSRange(location: 10, length: 0))))
        #expect(!KeyCommand.moveRight.reachesBeyondText(in: textView("app", selection: NSRange(location: 1, length: 0))))
    }

    @Test func selectedTextKeepsArrowsInTheField() {
        let selected = textView("app", selection: NSRange(location: 0, length: 3))
        #expect(!KeyCommand.moveLeft.reachesBeyondText(in: selected))
        #expect(!KeyCommand.moveRight.reachesBeyondText(in: selected))
    }

    @Test func otherCommandsAndMissingTextPass() {
        let typing = textView("app", selection: NSRange(location: 1, length: 0))
        #expect(KeyCommand.moveUp.reachesBeyondText(in: typing))
        #expect(KeyCommand.moveRight.reachesBeyondText(in: nil))
    }
}
