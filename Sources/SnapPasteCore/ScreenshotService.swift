import Foundation

public enum CaptureError: Error, Equatable, LocalizedError {
    /// e.g. "could not create image from display" when Screen Recording permission is missing.
    case screencaptureFailed(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case let .screencaptureFailed(status, message):
            return "screencapture (\(status)): \(message)"
        }
    }
}

/// Runs a capture and copies the result to the clipboard. Use from the main thread.
/// Only the most recent screenshot is kept on disk (for "copy again"); older ones are deleted.
public final class ScreenshotService {
    public enum Outcome: Equatable {
        case copied(URL)
        case cancelled
    }

    public private(set) var isCapturing = false
    public private(set) var lastScreenshotURL: URL?

    private let runner: ProcessRunning
    private let clipboard: ImageClipboard
    private let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL,
        runner: ProcessRunning = SystemProcessRunner(),
        clipboard: ImageClipboard = ImageClipboard(),
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.runner = runner
        self.clipboard = clipboard
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        lastScreenshotURL = pruneToNewestScreenshot()
    }

    public static func defaultDirectory(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(bundleIdentifier ?? "SnapPaste", isDirectory: true)
    }

    /// Returns false and does nothing if a capture is already running.
    @discardableResult
    public func capture(
        mode: CaptureMode,
        playSound: Bool,
        displayNumber: Int? = nil,
        completion: @escaping (Result<Outcome, Error>) -> Void
    ) -> Bool {
        guard !isCapturing else { return false }
        isCapturing = true

        let output = directory.appendingPathComponent("snap-\(UUID().uuidString).png")
        let arguments = CaptureCommand.arguments(mode: mode, playSound: playSound, displayNumber: displayNumber, output: output)
        do {
            try runner.run(CaptureCommand.executableURL, arguments: arguments) { [weak self] process in
                DispatchQueue.main.async {
                    self?.finish(output: output, interactive: mode != .fullScreen, process: process, completion: completion)
                }
            }
        } catch {
            isCapturing = false
            completion(.failure(error))
        }
        return true
    }

    /// Puts the last screenshot back on the clipboard (e.g. after copying something else).
    @discardableResult
    public func copyLastScreenshot() throws -> Bool {
        guard let url = lastScreenshotURL, fileManager.fileExists(atPath: url.path) else { return false }
        try clipboard.writePNG(at: url)
        return true
    }

    private func finish(output: URL, interactive: Bool, process: ProcessResult, completion: (Result<Outcome, Error>) -> Void) {
        isCapturing = false

        let size = (try? fileManager.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        guard size > 0 else {
            try? fileManager.removeItem(at: output)
            if interactive, Self.isUserCancellation(process) {
                completion(.success(.cancelled))
            } else {
                completion(.failure(CaptureError.screencaptureFailed(status: process.status, message: process.standardError)))
            }
            return
        }

        do {
            try clipboard.writePNG(at: output)
        } catch {
            try? fileManager.removeItem(at: output)
            completion(.failure(error))
            return
        }

        if let previous = lastScreenshotURL, previous != output {
            try? fileManager.removeItem(at: previous)
        }
        lastScreenshotURL = output
        completion(.success(.copied(output)))
    }

    /// Esc (or clicking without dragging) ends interactive mode without a file and either no
    /// output or a "…Cancelling" note; anything else, e.g. "could not create image from display"
    /// when Screen Recording permission is missing, is a real failure.
    static func isUserCancellation(_ process: ProcessResult) -> Bool {
        process.standardError.isEmpty || process.standardError.range(of: "cancel", options: .caseInsensitive) != nil
    }

    private func pruneToNewestScreenshot() -> URL? {
        let files = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        let screenshots = files
            .filter { $0.lastPathComponent.hasPrefix("snap-") && $0.pathExtension == "png" }
            .sorted { modificationDate($0) > modificationDate($1) }
        for stale in screenshots.dropFirst() {
            try? fileManager.removeItem(at: stale)
        }
        return screenshots.first
    }

    private func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
