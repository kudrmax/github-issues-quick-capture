import Testing
@testable import IssueBarCore

struct IssueDraftTests {
    @Test func singleLineBecomesTitleWithEmptyBody() throws {
        let draft = try #require(IssueDraft(text: "  Починить импорт  "))
        #expect(draft.title == "Починить импорт")
        #expect(draft.body == "")
    }

    @Test func remainingLinesBecomeBody() throws {
        let draft = try #require(IssueDraft(text: "Заголовок\n\nШаг 1\nШаг 2\n"))
        #expect(draft.title == "Заголовок")
        #expect(draft.body == "Шаг 1\nШаг 2")
    }

    @Test func blankTextIsNotADraft() {
        #expect(IssueDraft(text: " \n\t ") == nil)
    }

    @Test func longFirstLineIsShortenedAndKeptInBody() throws {
        let sentence = String(repeating: "слово ", count: 40).trimmingCharacters(in: .whitespaces)
        let draft = try #require(IssueDraft(text: sentence))

        #expect(draft.title.count <= IssueDraft.maxTitleLength)
        #expect(draft.title.hasSuffix("слово…"))
        #expect(draft.body == sentence)
    }
}
