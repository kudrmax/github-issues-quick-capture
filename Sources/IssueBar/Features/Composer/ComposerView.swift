import SwiftUI
import IssueBarCore

struct ComposerView: View {
    let segments: [DraftSegment]
    let resetToken: Int
    let focusToken: Int
    let isSubmitting: Bool
    let onChange: ([DraftSegment]) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            RichComposer(
                segments: segments,
                resetToken: resetToken,
                focusToken: focusToken,
                isEditable: !isSubmitting,
                onChange: onChange
            )
            if segments.isEmpty {
                Text("What needs to be done? The first line becomes the title. ⌘V pastes images.")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
    }
}
