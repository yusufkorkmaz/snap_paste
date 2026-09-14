import AppKit
@testable import SnapPasteCore
import XCTest

enum TestImages {
    /// Writes a solid-colour PNG of the given pixel size and returns its URL.
    static func writePNG(width: Int = 40, height: Int = 20, to url: URL) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}

final class TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapPasteTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

func makePrivatePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("SnapPasteTests-\(UUID().uuidString)"))
}

/// Stands in for `screencapture`: records calls and optionally "captures" by writing a PNG.
final class FakeRunner: ProcessRunning {
    enum Behavior {
        case writePNG(width: Int, height: Int)
        case writeNothing(exitStatus: Int32, stderr: String = "")
        case writeGarbage
        case failToLaunch
        case hang
    }

    struct LaunchError: Error {}

    var behavior: Behavior
    private(set) var calls: [(executable: URL, arguments: [String])] = []
    private(set) var pendingCompletion: ((ProcessResult) -> Void)?

    init(_ behavior: Behavior) {
        self.behavior = behavior
    }

    func run(_ executable: URL, arguments: [String], completion: @escaping (ProcessResult) -> Void) throws {
        calls.append((executable, arguments))
        let output = URL(fileURLWithPath: arguments.last!)
        switch behavior {
        case let .writePNG(width, height):
            try TestImages.writePNG(width: width, height: height, to: output)
            completion(ProcessResult(status: 0))
        case let .writeNothing(status, stderr):
            completion(ProcessResult(status: status, standardError: stderr))
        case .writeGarbage:
            try Data("not a png".utf8).write(to: output)
            completion(ProcessResult(status: 0))
        case .failToLaunch:
            throw LaunchError()
        case .hang:
            pendingCompletion = completion
        }
    }
}
