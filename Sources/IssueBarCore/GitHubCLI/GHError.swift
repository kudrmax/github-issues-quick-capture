import Foundation

public enum GHError: LocalizedError, Equatable {
    case notInstalled
    case notAuthenticated
    case commandFailed(String)
    case unexpectedOutput(String)

    static func fromFailure(stderr: String) -> GHError {
        let lowercased = stderr.lowercased()
        if lowercased.contains("gh auth login") || lowercased.contains("not logged in") {
            return .notAuthenticated
        }
        return .commandFailed(stderr)
    }

    public var errorDescription: String? {
        switch self {
        case .notInstalled:
            "GitHub CLI not found. Install it: brew install gh"
        case .notAuthenticated:
            "gh is not logged in. Run in Terminal: gh auth login"
        case .commandFailed(let message):
            message.isEmpty ? "gh command failed" : message
        case .unexpectedOutput(let output):
            "Unexpected gh output: \(output)"
        }
    }
}
