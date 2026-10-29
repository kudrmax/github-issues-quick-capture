import Foundation
import Testing
import IssueBarCore

struct GitHubUserTests {
    @Test func avatarURLAddressesLoginDirectly() {
        let url = GitHubUser(login: "kudrmax").avatarURL(pixelSize: 64)
        #expect(url?.absoluteString == "https://avatars.githubusercontent.com/kudrmax?s=64")
    }

    @Test func avatarURLEscapesBotLogins() {
        let url = GitHubUser(login: "dependabot[bot]").avatarURL(pixelSize: 64)
        #expect(url?.absoluteString == "https://avatars.githubusercontent.com/dependabot%5Bbot%5D?s=64")
    }

    @Test func emptyLoginHasNoAvatar() {
        let user = GitHubUser(login: "")
        #expect(user.avatarURL(pixelSize: 64) == nil)
        #expect(user.initial == "?")
    }

    @Test func initialIsUppercasedFirstLetter() {
        #expect(GitHubUser(login: "ismylvdya").initial == "I")
    }

    @Test func hueIsStableAndCaseInsensitive() {
        #expect(GitHubUser(login: "kudrmax").hue == GitHubUser(login: "KudrMax").hue)
        #expect((0..<1).contains(GitHubUser(login: "kudrmax").hue))
    }

    @Test func differentLoginsGetDifferentHues() {
        #expect(GitHubUser(login: "kudrmax").hue != GitHubUser(login: "ismylvdya").hue)
    }
}
