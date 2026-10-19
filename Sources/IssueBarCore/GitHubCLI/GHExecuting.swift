import Foundation

public protocol GHExecuting: Sendable {
    /// `input` is fed to stdin, for `gh api --input -` with bodies too large for arguments.
    func run(_ arguments: [String], input: Data?) async throws -> Data
}

extension GHExecuting {
    public func run(_ arguments: [String]) async throws -> Data {
        try await run(arguments, input: nil)
    }
}
