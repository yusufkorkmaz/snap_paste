import AppKit
@testable import SnapPasteCore
import XCTest

final class ScreenshotServiceTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var temp: TemporaryDirectory!

    override func setUpWithError() throws {
        pasteboard = makePrivatePasteboard()
        temp = try TemporaryDirectory()
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        temp = nil
    }

    private func makeService(_ runner: FakeRunner) throws -> ScreenshotService {
        try ScreenshotService(directory: temp.url, runner: runner, clipboard: ImageClipboard(pasteboard: pasteboard))
    }

    private func capture(
        _ service: ScreenshotService,
        mode: CaptureMode = .region,
        playSound: Bool = true,
        displayNumber: Int? = nil
    ) -> Result<ScreenshotService.Outcome, Error> {
        let done = expectation(description: "capture finished")
        var result: Result<ScreenshotService.Outcome, Error>?
        XCTAssertTrue(service.capture(mode: mode, playSound: playSound, displayNumber: displayNumber) {
            result = $0
            done.fulfill()
        })
        wait(for: [done], timeout: 5)
        return result!
    }

    private func pngFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: temp.url, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
    }

    func testSuccessfulCaptureLandsOnClipboard() throws {
        let service = try makeService(FakeRunner(.writePNG(width: 80, height: 50)))
        guard case let .success(.copied(url)) = capture(service) else { return XCTFail("expected copied") }

        XCTAssertEqual(service.lastScreenshotURL, url)
        XCTAssertEqual(pasteboard.data(forType: .png), try Data(contentsOf: url))
        XCTAssertEqual(NSImage(pasteboard: pasteboard)?.representations.first?.pixelsWide, 80)
        XCTAssertFalse(service.isCapturing)
    }

    func testPassesModeSoundAndDisplayToScreencapture() throws {
        let runner = FakeRunner(.writePNG(width: 4, height: 4))
        let service = try makeService(runner)
        _ = capture(service, mode: .fullScreen, playSound: false, displayNumber: 2)

        let call = try XCTUnwrap(runner.calls.first)
        XCTAssertEqual(call.executable, CaptureCommand.executableURL)
        XCTAssertEqual(Array(call.arguments.dropLast()), ["-D", "2", "-x", "-t", "png"])
        XCTAssertEqual(URL(fileURLWithPath: call.arguments.last!).deletingLastPathComponent().standardizedFileURL, temp.url.standardizedFileURL)
    }

    func testCancelledCaptureKeepsClipboardUntouched() throws {
        pasteboard.clearContents()
        pasteboard.setString("kopyalanmış metin", forType: .string)
        let service = try makeService(FakeRunner(.writeNothing(exitStatus: 1)))

        guard case .success(.cancelled) = capture(service) else { return XCTFail("expected cancelled") }
        XCTAssertEqual(pasteboard.string(forType: .string), "kopyalanmış metin")
        XCTAssertNil(service.lastScreenshotURL)
        XCTAssertEqual(try pngFiles(), [])
    }

    func testCancellationNoteOnStderrIsStillACancel() throws {
        let service = try makeService(FakeRunner(.writeNothing(exitStatus: 1, stderr: "No selection to capture. Cancelling")))
        guard case .success(.cancelled) = capture(service, mode: .window) else { return XCTFail("expected cancelled") }
    }

    func testMissingPermissionIsAFailureNotACancel() throws {
        pasteboard.clearContents()
        pasteboard.setString("dokunma", forType: .string)
        let service = try makeService(FakeRunner(.writeNothing(exitStatus: 1, stderr: "could not create image from display")))

        guard case let .failure(error) = capture(service) else { return XCTFail("expected failure") }
        XCTAssertEqual(error as? CaptureError, .screencaptureFailed(status: 1, message: "could not create image from display"))
        XCTAssertTrue(error.localizedDescription.contains("could not create image from display"))
        XCTAssertEqual(pasteboard.string(forType: .string), "dokunma")
        XCTAssertEqual(try pngFiles(), [])
    }

    func testFullScreenWithoutImageIsAlwaysAFailure() throws {
        // Full-screen capture has no UI to cancel from, so a missing file can only mean an error.
        let service = try makeService(FakeRunner(.writeNothing(exitStatus: 0)))
        guard case .failure = capture(service, mode: .fullScreen) else { return XCTFail("expected failure") }
        XCTAssertFalse(service.isCapturing)
    }

    func testCancellationClassification() {
        XCTAssertTrue(ScreenshotService.isUserCancellation(ProcessResult(status: 1)))
        XCTAssertTrue(ScreenshotService.isUserCancellation(ProcessResult(status: 0)))
        XCTAssertTrue(ScreenshotService.isUserCancellation(ProcessResult(status: 1, standardError: "CANCELLED by user")))
        XCTAssertFalse(ScreenshotService.isUserCancellation(ProcessResult(status: 1, standardError: "screencapture: capture error")))
    }

    func testOnlyNewestScreenshotIsKeptOnDisk() throws {
        let service = try makeService(FakeRunner(.writePNG(width: 4, height: 4)))
        guard case let .success(.copied(first)) = capture(service),
              case let .success(.copied(second)) = capture(service)
        else { return XCTFail("expected two captures") }

        XCTAssertNotEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(try pngFiles().map(\.lastPathComponent), [second.lastPathComponent])
    }

    func testCancelDoesNotDeletePreviousScreenshot() throws {
        let runner = FakeRunner(.writePNG(width: 4, height: 4))
        let service = try makeService(runner)
        guard case let .success(.copied(first)) = capture(service) else { return XCTFail() }

        runner.behavior = .writeNothing(exitStatus: 1)
        _ = capture(service)
        XCTAssertEqual(service.lastScreenshotURL, first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
    }

    func testSecondCaptureWhileRunningIsIgnored() throws {
        let runner = FakeRunner(.hang)
        let service = try makeService(runner)

        XCTAssertTrue(service.capture(mode: .region, playSound: true) { _ in })
        XCTAssertTrue(service.isCapturing)
        XCTAssertFalse(service.capture(mode: .region, playSound: true) { _ in XCTFail("must not run") })
        XCTAssertEqual(runner.calls.count, 1)

        let done = expectation(description: "finished")
        runner.pendingCompletion?(ProcessResult(status: 1))
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
        XCTAssertFalse(service.isCapturing)
    }

    func testLaunchFailureIsReportedAndResetsState() throws {
        let service = try makeService(FakeRunner(.failToLaunch))
        var result: Result<ScreenshotService.Outcome, Error>?
        service.capture(mode: .region, playSound: true) { result = $0 }

        guard case .failure = result else { return XCTFail("expected synchronous failure") }
        XCTAssertFalse(service.isCapturing)
    }

    func testInvalidImageIsReportedAndDiscarded() throws {
        let service = try makeService(FakeRunner(.writeGarbage))
        guard case let .failure(error) = capture(service) else { return XCTFail("expected failure") }
        XCTAssertTrue(error is ClipboardError)
        XCTAssertEqual(try pngFiles(), [])
        XCTAssertNil(service.lastScreenshotURL)
    }

    func testCopyLastScreenshotRestoresClipboard() throws {
        let service = try makeService(FakeRunner(.writePNG(width: 9, height: 9)))
        XCTAssertFalse(try service.copyLastScreenshot(), "nothing captured yet")

        guard case let .success(.copied(url)) = capture(service) else { return XCTFail() }
        pasteboard.clearContents()
        pasteboard.setString("başka bir şey", forType: .string)

        XCTAssertTrue(try service.copyLastScreenshot())
        XCTAssertEqual(pasteboard.data(forType: .png), try Data(contentsOf: url))
    }

    func testStartupKeepsOnlyNewestLeftoverScreenshot() throws {
        let fm = FileManager.default
        var urls: [URL] = []
        for (index, age) in [300.0, 10.0, 1000.0].enumerated() {
            let url = temp.url.appendingPathComponent("snap-\(index).png")
            try TestImages.writePNG(width: 2, height: 2, to: url)
            try fm.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: url.path)
            urls.append(url)
        }
        let unrelated = temp.url.appendingPathComponent("notes.txt")
        try Data("keep".utf8).write(to: unrelated)

        let service = try makeService(FakeRunner(.writeNothing(exitStatus: 0)))

        XCTAssertEqual(service.lastScreenshotURL?.lastPathComponent, "snap-1.png")
        XCTAssertEqual(try pngFiles().map(\.lastPathComponent), ["snap-1.png"])
        XCTAssertTrue(fm.fileExists(atPath: unrelated.path))
    }

    func testCreatesMissingDirectory() throws {
        let nested = temp.url.appendingPathComponent("a/b/c", isDirectory: true)
        _ = try ScreenshotService(directory: nested, runner: FakeRunner(.hang), clipboard: ImageClipboard(pasteboard: pasteboard))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testDefaultDirectoryIsInCachesAndNamespaced() {
        let url = ScreenshotService.defaultDirectory(bundleIdentifier: "com.example.test")
        XCTAssertEqual(url.lastPathComponent, "com.example.test")
        XCTAssertTrue(url.path.contains("/Library/Caches/"))
    }
}
