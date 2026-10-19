import Foundation
import Testing
@testable import IssueBarCore

struct DiskImageCacheTests {
    private let defaults = UserDefaults(suiteName: "IssueBarImageCache.\(UUID().uuidString)")!

    private func makeCache() -> (DiskImageCache, URL) {
        let directory = FileManager.default.temporaryDirectory.appending(path: "IssueBarImageCache-\(UUID().uuidString)")
        return (DiskImageCache(directory: directory, defaults: defaults), directory)
    }

    @Test func storedImageIsReturnedAndClearedOnRequest() {
        let (cache, _) = makeCache()
        let url = URL(string: "https://raw.githubusercontent.com/me/app/issue-attachments/images/a.png")!
        cache.store(Data([1, 2, 3]), for: url)

        #expect(cache.data(for: url) == Data([1, 2, 3]))
        cache.removeAll()
        #expect(cache.data(for: url) == nil)
    }

    @Test func imagesPersistOnDiskForTheNextLaunch() async throws {
        let (cache, directory) = makeCache()
        let url = URL(string: "https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true")!
        cache.store(Data(repeating: 7, count: 4096), for: url)

        let relaunched = DiskImageCache(directory: directory, defaults: defaults)
        var data: Data?
        for _ in 0..<100 {
            data = relaunched.data(for: url)
            if data != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(data == Data(repeating: 7, count: 4096))
    }

    @Test func clearingSurvivesARelaunch() async throws {
        let (cache, directory) = makeCache()
        let url = URL(string: "https://img.test/a.png")!
        cache.store(Data([1]), for: url)
        cache.removeAll()

        #expect(DiskImageCache(directory: directory, defaults: defaults).data(for: url) == nil)
    }

    @Test func newImagesAreCachedAfterClearing() {
        let (cache, _) = makeCache()
        let url = URL(string: "https://img.test/a.png")!
        cache.removeAll()
        cache.store(Data([2]), for: url)
        #expect(cache.data(for: url) == Data([2]))
    }

    @Test func gitHubKeysDropSignaturesAndFlags() {
        #expect(DiskImageCache.key(for: URL(string: "https://private-user-images.githubusercontent.com/1/a.png?jwt=xyz")!)
            == URL(string: "https://private-user-images.githubusercontent.com/1/a.png")!)
        #expect(DiskImageCache.key(for: URL(string: "https://github.com/me/app/blob/b/a.png?raw=true")!)
            == URL(string: "https://github.com/me/app/blob/b/a.png")!)
    }

    @Test func otherHostsKeepTheirQuery() {
        let url = URL(string: "https://img.test/render?id=5")!
        #expect(DiskImageCache.key(for: url) == url)
    }
}
