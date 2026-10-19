import Foundation
import Testing
@testable import IssueBarCore

struct IssueFilterTests {
    private let filter = IssueFilter()
    private let issues = [
        Issue(number: 12, title: "Падает импорт EPUB", url: URL(string: "https://github.com/me/r/issues/12")!, author: "max", createdAt: .now, labels: ["bug"]),
        Issue(number: 7, title: "Добавить тёмную тему", url: URL(string: "https://github.com/me/r/issues/7")!, author: "agent", createdAt: .now),
    ]

    @Test func emptyQueryKeepsEverything() {
        #expect(filter.filter(issues, query: "  ").count == 2)
    }

    @Test func everyWordMustMatchAcrossFields() {
        #expect(filter.filter(issues, query: "импорт bug").map(\.number) == [12])
        #expect(filter.filter(issues, query: "импорт agent").isEmpty)
    }

    @Test func matchesByNumberAndIgnoresCase() {
        #expect(filter.filter(issues, query: "#7").map(\.number) == [7])
        #expect(filter.filter(issues, query: "ТЁМНУЮ").map(\.number) == [7])
    }
}
