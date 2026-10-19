import Foundation

public final class ProcessGHExecutor: GHExecuting {
    private let locator: GHExecutableLocator

    public init(locator: GHExecutableLocator = GHExecutableLocator()) {
        self.locator = locator
    }

    public func run(_ arguments: [String], input: Data?) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [locator] in
                continuation.resume(with: Result {
                    guard let executable = locator.locate() else { throw GHError.notInstalled }
                    return try Self.execute(executable, arguments, input: input)
                })
            }
        }
    }

    private static func execute(_ executable: URL, _ arguments: [String], input: Data?) throws -> Data {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment()
        let stdin = input.map { _ in Pipe() }
        process.standardInput = stdin ?? FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()

        if let stdin, let input {
            DispatchQueue.global(qos: .userInitiated).async {
                stdin.fileHandleForWriting.write(input)
                try? stdin.fileHandleForWriting.close()
            }
        }
        let errorOutput = PipeReader(stderr)
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorOutput.waitForData()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw GHError.fromFailure(stderr: message)
        }
        return output
    }

    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let systemPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = [environment["PATH"], systemPath].compactMap { $0 }.joined(separator: ":")
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["GH_SPINNER_DISABLED"] = "1"
        environment["NO_COLOR"] = "1"
        return environment
    }
}

/// Drains a pipe on a background queue so a chatty stderr can't block the process.
private final class PipeReader: @unchecked Sendable {
    private var data = Data()
    private let group = DispatchGroup()

    init(_ pipe: Pipe) {
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
    }

    func waitForData() -> Data {
        group.wait()
        return data
    }
}
