import Foundation

public struct ProcessResult: Equatable {
    public var status: Int32
    public var standardError: String

    public init(status: Int32, standardError: String = "") {
        self.status = status
        self.standardError = standardError
    }
}

public protocol ProcessRunning {
    /// Launches `executable`; `completion` is called exactly once when it exits, on any thread.
    func run(_ executable: URL, arguments: [String], completion: @escaping (ProcessResult) -> Void) throws
}

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executable: URL, arguments: [String], completion: @escaping (ProcessResult) -> Void) throws {
        let process = Process()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.qualityOfService = .userInteractive
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderr
        process.terminationHandler = { finished in
            // screencapture only prints a short line on failure, well under the pipe buffer.
            let message = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            completion(ProcessResult(
                status: finished.terminationStatus,
                standardError: message.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        try process.run()
    }
}
