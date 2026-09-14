@testable import SnapPasteCore
import XCTest

final class CaptureCommandTests: XCTestCase {
    private let output = URL(fileURLWithPath: "/tmp/dir with space/snap.png")

    func testExecutableIsSystemScreencapture() {
        XCTAssertEqual(CaptureCommand.executableURL.path, "/usr/sbin/screencapture")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: CaptureCommand.executableURL.path))
    }

    func testRegionModeIsInteractive() {
        XCTAssertEqual(
            CaptureCommand.arguments(mode: .region, playSound: true, output: output),
            ["-i", "-t", "png", "/tmp/dir with space/snap.png"]
        )
    }

    func testWindowModeStartsInWindowSelection() {
        XCTAssertEqual(
            CaptureCommand.arguments(mode: .window, playSound: true, output: output),
            ["-i", "-W", "-t", "png", output.path]
        )
    }

    func testFullScreenTargetsGivenDisplay() {
        XCTAssertEqual(
            CaptureCommand.arguments(mode: .fullScreen, playSound: true, displayNumber: 2, output: output),
            ["-D", "2", "-t", "png", output.path]
        )
    }

    func testFullScreenFallsBackToMainDisplay() {
        XCTAssertEqual(
            CaptureCommand.arguments(mode: .fullScreen, playSound: true, output: output),
            ["-m", "-t", "png", output.path]
        )
    }

    func testDisplayNumberIsIgnoredOutsideFullScreen() {
        XCTAssertEqual(
            CaptureCommand.arguments(mode: .region, playSound: true, displayNumber: 3, output: output),
            ["-i", "-t", "png", output.path]
        )
    }

    func testSilentAddsMuteFlag() {
        for mode in CaptureMode.allCases {
            let args = CaptureCommand.arguments(mode: mode, playSound: false, output: output)
            XCTAssertTrue(args.contains("-x"), "\(mode)")
            XCTAssertEqual(args.last, output.path, "output must stay the final argument")
        }
    }

    func testDisplayNumberUnderPoint() {
        let displays = [
            CGRect(x: 0, y: 0, width: 1512, height: 982), // main
            CGRect(x: 1512, y: -200, width: 2560, height: 1440), // right
            CGRect(x: -1920, y: 0, width: 1920, height: 1080), // left
        ]
        XCTAssertEqual(CaptureCommand.displayNumber(containing: CGPoint(x: 10, y: 10), displayBounds: displays), 1)
        XCTAssertEqual(CaptureCommand.displayNumber(containing: CGPoint(x: 2000, y: -100), displayBounds: displays), 2)
        XCTAssertEqual(CaptureCommand.displayNumber(containing: CGPoint(x: -5, y: 500), displayBounds: displays), 3)
    }

    func testDisplayEdgeBelongsToDisplayStartingThere() {
        let displays = [CGRect(x: 0, y: 0, width: 100, height: 100), CGRect(x: 100, y: 0, width: 100, height: 100)]
        XCTAssertEqual(CaptureCommand.displayNumber(containing: CGPoint(x: 100, y: 50), displayBounds: displays), 2)
    }

    func testPointOutsideAllDisplays() {
        XCTAssertNil(CaptureCommand.displayNumber(containing: CGPoint(x: 5000, y: 5000), displayBounds: [CGRect(x: 0, y: 0, width: 100, height: 100)]))
        XCTAssertNil(CaptureCommand.displayNumber(containing: .zero, displayBounds: []))
    }

    func testDisplayUnderMouseOnThisMac() throws {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        try XCTSkipIf(count == 0, "no active display")
        let number = try XCTUnwrap(CaptureCommand.displayNumberUnderMouse())
        XCTAssertTrue((1 ... Int(count)).contains(number))
    }
}
