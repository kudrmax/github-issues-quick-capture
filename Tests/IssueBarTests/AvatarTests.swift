import AppKit
import Testing
@testable import IssueBar
import IssueBarCore

@MainActor
struct AvatarTests {
    private let user = GitHubUser(login: "max")
    private let images = StubImageLoader()
    private let model: IssueBarViewModel

    init() {
        model = makeModel(tracker: StubTracker(repositories: []), images: images)
    }

    private var avatarURL: URL { user.avatarURL(pixelSize: 64)! }

    private func stubPhoto() {
        let photo = NSImage.snapshotGradient(.systemTeal, .systemBlue, size: NSSize(width: 64, height: 64))
        images.images[avatarURL] = NSBitmapImageRep(data: photo.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    }

    @Test func rowsOfOneAuthorShareOneRequest() async {
        stubPhoto()

        let rows = (0..<3).map { _ in Task { await model.avatar(for: user) != nil } }
        var loaded: [Bool] = []
        for row in rows { loaded.append(await row.value) }

        #expect(loaded == [true, true, true])
        #expect(images.requested == [avatarURL])
    }

    @Test func loadedAvatarIsAvailableWithoutWaiting() async {
        stubPhoto()
        #expect(model.loadedAvatar(for: user) == nil)

        _ = await model.avatar(for: user)

        #expect(model.loadedAvatar(for: user) != nil)
        _ = await model.avatar(for: user)
        #expect(images.requested == [avatarURL])
    }

    @Test func failedAvatarIsRetriedOnNextAsk() async {
        #expect(await model.avatar(for: user) == nil)

        stubPhoto()

        #expect(await model.avatar(for: user) != nil)
        #expect(images.requested == [avatarURL, avatarURL])
    }

    @Test func authorWithoutLoginRequestsNothing() async {
        #expect(await model.avatar(for: GitHubUser(login: "")) == nil)
        #expect(images.requested.isEmpty)
    }
}
