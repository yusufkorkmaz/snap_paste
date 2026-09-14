import AppKit
@testable import SnapPasteCore
import XCTest

/// Runs the real /usr/sbin/screencapture non-interactively (full screen, silent).
final class ScreencaptureIntegrationTests: XCTestCase {
    private var pasteboard: NSPasteboard!
    private var temp: TemporaryDirectory!

    override func setUpWithError() throws {
        try XCTSkipIf(CGMainDisplayID() == 0 || NSScreen.screens.isEmpty, "requires a logged-in GUI session")
        pasteboard = makePrivatePasteboard()
        temp = try TemporaryDirectory()
    }

    override func tearDown() {
        pasteboard?.releaseGlobally()
        temp = nil
    }

    func testSystemRunnerReportsExitStatusAndStderr() throws {
        let done = expectation(description: "exit")
        var result: ProcessResult?
        try SystemProcessRunner().run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo ignored; echo '  boom  ' >&2; exit 7"]) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(result, ProcessResult(status: 7, standardError: "boom"))
    }

    func testSystemRunnerHandlesLargeStderr() throws {
        let done = expectation(description: "exit")
        var result: ProcessResult?
        // 8 KB of stderr must neither deadlock nor be truncated.
        try SystemProcessRunner().run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf '%08000d' 0 >&2"]) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(result?.status, 0)
        XCTAssertEqual(result?.standardError, String(repeating: "0", count: 8000))
    }

    func testSystemRunnerThrowsForMissingExecutable() {
        XCTAssertThrowsError(try SystemProcessRunner().run(URL(fileURLWithPath: "/nonexistent/tool"), arguments: []) { _ in })
    }

    func testFullScreenCaptureEndToEnd() throws {
        try XCTSkipUnless(ScreenRecordingPermission.isGranted, "test runner lacks Screen Recording permission")
        let service = try ScreenshotService(directory: temp.url, clipboard: ImageClipboard(pasteboard: pasteboard))
        let done = expectation(description: "captured")
        var result: Result<ScreenshotService.Outcome, Error>?
        let started = Date()
        service.capture(mode: .fullScreen, playSound: false, displayNumber: 1) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: 20)

        guard case let .success(.copied(url)) = result else { return XCTFail("capture failed: \(String(describing: result))") }
        print("screencapture full-screen round trip: \(Int(Date().timeIntervalSince(started) * 1000)) ms")

        let rep = try XCTUnwrap(pasteboard.data(forType: .png).flatMap(NSBitmapImageRep.init(data:)))
        let expectedWidth = CGDisplayPixelsWide(CGMainDisplayID())
        XCTAssertGreaterThan(rep.pixelsWide, 0)
        XCTAssertGreaterThanOrEqual(rep.pixelsWide, expectedWidth, "should be at least the main display's point width")
        XCTAssertEqual(try Data(contentsOf: url), pasteboard.data(forType: .png))
        XCTAssertNotNil(NSImage(pasteboard: pasteboard))
    }
}
