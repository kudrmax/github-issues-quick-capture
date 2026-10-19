import Foundation
import Testing
@testable import IssueBarCore

struct IssueBodyParserTests {
    private let parser = IssueBodyParser()
    private let attached = URL(string: "https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true")!

    @Test func listsAndImageFromARealIssue() {
        let body = """
        - Добавить TTS
        - Кнопка другие буквы переназначить

        ![image](https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true)
        """
        #expect(parser.parse(markdown: body) == [
            .listItem(marker: "•", text: "Добавить TTS"),
            .listItem(marker: "•", text: "Кнопка другие буквы переназначить"),
            .image(attached),
        ])
    }

    @Test func consecutiveLinesFormOneParagraphAndBlankLinesSplitThem() {
        let body = "Первая строка\nвторая строка\n\nНовый абзац"
        #expect(parser.parse(markdown: body) == [.paragraph("Первая строка\nвторая строка"), .paragraph("Новый абзац")])
    }

    @Test func imagesBetweenTextKeepTheirOrder() {
        let body = "Вот что вижу:\n![image](https://img.test/1.png)\nА потом:\n![image](https://img.test/2.png)\nКонец"
        #expect(parser.parse(markdown: body) == [
            .paragraph("Вот что вижу:"), .image(URL(string: "https://img.test/1.png")!),
            .paragraph("А потом:"), .image(URL(string: "https://img.test/2.png")!),
            .paragraph("Конец"),
        ])
    }

    @Test func inlineImageGetsItsOwnBlock() {
        #expect(parser.parse(markdown: "до ![x](https://img.test/1.png) после") == [
            .paragraph("до"), .image(URL(string: "https://img.test/1.png")!), .paragraph("после"),
        ])
    }

    @Test func htmlImageTagFromWebUploadIsAnImage() {
        let body = #"<img width="600" alt="Screenshot" src="https://github.com/user-attachments/assets/abc-123" />"#
        #expect(parser.parse(markdown: body) == [.image(URL(string: "https://github.com/user-attachments/assets/abc-123")!)])
    }

    @Test func headingsCodeQuotesRulesAndNumberedLists() {
        let body = """
        ## Шаги
        1. Открыть
        2. Нажать
        > цитата
        ---
        ```
        let x = 1
          indented
        ```
        - [ ] сделать
        - [x] готово
        """
        #expect(parser.parse(markdown: body) == [
            .heading(level: 2, text: "Шаги"),
            .listItem(marker: "1.", text: "Открыть"),
            .listItem(marker: "2.", text: "Нажать"),
            .quote("цитата"),
            .rule,
            .code("let x = 1\n  indented"),
            .listItem(marker: "☐", text: "сделать"),
            .listItem(marker: "☑", text: "готово"),
        ])
    }

    @Test func hashtagWithoutSpaceIsNotAHeading() {
        #expect(parser.parse(markdown: "#12 упал") == [.paragraph("#12 упал")])
    }

    @Test func webUploadsAreReplacedWithSignedURLsFromHTML() {
        let body = """
        ![one](https://github.com/user-attachments/assets/1)
        ![mine](https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true)
        """
        let html = """
        <p><img src="https://private-user-images.githubusercontent.com/1.png?jwt=abc&amp;x=1"></p>
        <p><img src="https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true"></p>
        """
        #expect(parser.parse(markdown: body, html: html) == [
            .image(URL(string: "https://private-user-images.githubusercontent.com/1.png?jwt=abc&x=1")!),
            .image(attached),
        ])
    }

    @Test func mismatchedHTMLImagesAreIgnored() {
        let body = "![one](https://github.com/user-attachments/assets/1)"
        let html = #"<img src="https://a.test/1.png"><img src="https://a.test/2.png">"#
        #expect(parser.parse(markdown: body, html: html) == [.image(URL(string: "https://github.com/user-attachments/assets/1")!)])
    }

    @Test func emptyBodyHasNoBlocks() {
        #expect(parser.parse(markdown: "  \n\n ").isEmpty)
    }
}

struct IssueDetailTrackerTests {
    @Test func parsesDetailWithLabelsAndSignedImages() async throws {
        let gh = FakeGH(output: """
        {"number":7,"title":"Переработать управление","html_url":"https://github.com/me/app/issues/7",
         "user":{"login":"kudrmax"},"created_at":"2026-10-19T20:00:00Z","updated_at":"2026-10-19T21:30:00Z",
         "labels":[{"name":"enhancement","color":"a2eeef","description":"New feature"}],
         "body":"Текст\\n![image](https://github.com/user-attachments/assets/1)",
         "body_html":"<p>Текст</p><p><img src=\\"https://private-user-images.githubusercontent.com/1.png?jwt=t\\"></p>"}
        """)
        let detail = try await GHIssueTracker(gh: gh).issueDetail(number: 7, in: Repository(nameWithOwner: "me/app"))

        #expect(detail.title == "Переработать управление")
        #expect(detail.author == "kudrmax")
        #expect(detail.updatedAt == ISO8601DateFormatter().date(from: "2026-10-19T21:30:00Z"))
        #expect(detail.labels == [IssueLabel(name: "enhancement", color: "a2eeef", description: "New feature")])
        #expect(detail.blocks == [.paragraph("Текст"), .image(URL(string: "https://private-user-images.githubusercontent.com/1.png?jwt=t")!)])
        #expect(gh.calls.first?.arguments == ["api", "repos/me/app/issues/7", "-H", "Accept: application/vnd.github.full+json"])
    }

    @Test func issueWithoutBodyHasNoBlocks() async throws {
        let gh = FakeGH(output: """
        {"number":1,"title":"T","html_url":"https://github.com/me/app/issues/1","user":null,
         "created_at":"2026-10-19T20:00:00Z","labels":[],"body":null,"body_html":null}
        """)
        let detail = try await GHIssueTracker(gh: gh).issueDetail(number: 1, in: Repository(nameWithOwner: "me/app"))
        #expect(detail.blocks.isEmpty)
        #expect(detail.author == "")
    }
}

struct GitHubImageLoaderTests {
    private final class FakeHTTP: HTTPDataFetching, @unchecked Sendable {
        var status = 200
        private(set) var requests: [URLRequest] = []

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data([0x89, 0x50]), response)
        }
    }

    @Test func attachedRepositoryImagesUseRawHostWithToken() async throws {
        let http = FakeHTTP()
        let gh = FakeGH(output: "gho_test\n")
        let loader = GitHubImageLoader(gh: gh, cache: MemoryImageCache(), http: http)
        let url = URL(string: "https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true")!

        _ = try await loader.imageData(for: url)
        _ = try await loader.imageData(for: URL(string: "https://github.com/me/app/raw/main/docs/b.png")!)

        #expect(http.requests.map(\.url?.absoluteString) == [
            "https://raw.githubusercontent.com/me/app/issue-attachments/images/a.png",
            "https://raw.githubusercontent.com/me/app/main/docs/b.png",
        ])
        #expect(http.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "token gho_test" })
        #expect(gh.calls.count == 1)
    }

    @Test func otherURLsAreFetchedAsIsWithoutToken() async throws {
        let http = FakeHTTP()
        let gh = FakeGH(output: "gho_test")
        let signed = URL(string: "https://private-user-images.githubusercontent.com/1.png?jwt=t")!

        _ = try await GitHubImageLoader(gh: gh, cache: MemoryImageCache(), http: http).imageData(for: signed)

        #expect(http.requests.first?.url == signed)
        #expect(http.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(gh.calls.isEmpty)
    }

    @Test func repeatedRequestsAreServedFromCache() async throws {
        let http = FakeHTTP()
        let loader = GitHubImageLoader(gh: FakeGH(output: "t"), cache: MemoryImageCache(), http: http)
        let url = URL(string: "https://img.test/1.png")!
        _ = try await loader.imageData(for: url)
        _ = try await loader.imageData(for: url)
        #expect(http.requests.count == 1)
    }

    @Test func signedURLsWithFreshSignaturesShareOneCacheEntry() async throws {
        let http = FakeHTTP()
        let loader = GitHubImageLoader(gh: FakeGH(output: "t"), cache: MemoryImageCache(), http: http)
        _ = try await loader.imageData(for: URL(string: "https://private-user-images.githubusercontent.com/1/abc.png?jwt=first")!)
        _ = try await loader.imageData(for: URL(string: "https://private-user-images.githubusercontent.com/1/abc.png?jwt=second")!)
        #expect(http.requests.count == 1)
    }

    @Test func imagesSurviveARelaunchThroughTheSharedCache() async throws {
        let cache = MemoryImageCache()
        let url = URL(string: "https://github.com/me/app/blob/issue-attachments/images/a.png?raw=true")!
        _ = try await GitHubImageLoader(gh: FakeGH(output: "t"), cache: cache, http: FakeHTTP()).imageData(for: url)

        let http = FakeHTTP()
        let gh = FakeGH(output: "t")
        let data = try await GitHubImageLoader(gh: gh, cache: cache, http: http).imageData(for: url)

        #expect(data == Data([0x89, 0x50]))
        #expect(http.requests.isEmpty)
        #expect(gh.calls.isEmpty)
    }

    @Test func failedDownloadsAreNotCached() async throws {
        let http = FakeHTTP()
        http.status = 500
        let cache = MemoryImageCache()
        let url = URL(string: "https://img.test/x.png")!
        _ = try? await GitHubImageLoader(gh: FakeGH(output: "t"), cache: cache, http: http).imageData(for: url)
        #expect(cache.data(for: url) == nil)
    }

    @Test func httpErrorsAreReported() async {
        let http = FakeHTTP()
        http.status = 404
        await #expect(throws: ImageLoadingError.http(404)) {
            try await GitHubImageLoader(gh: FakeGH(output: "t"), cache: MemoryImageCache(), http: http).imageData(for: URL(string: "https://img.test/x.png")!)
        }
    }
}
