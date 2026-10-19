import Foundation

/// GUI apps don't inherit the shell PATH, so `gh` is looked up in the usual
/// install locations first and then through a login shell.
public struct GHExecutableLocator: Sendable {
    public static let defaultCandidates = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        NSHomeDirectory() + "/.local/bin/gh",
    ]

    private let candidates: [String]

    public init(candidates: [String] = Self.defaultCandidates) {
        self.candidates = candidates
    }

    public func locate() -> URL? {
        let fileManager = FileManager.default
        if let path = candidates.first(where: fileManager.isExecutableFile(atPath:)) {
            return URL(fileURLWithPath: path)
        }
        return locateThroughLoginShell()
    }

    private func locateThroughLoginShell() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v gh"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let path = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
