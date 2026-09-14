import AppKit
@testable import SnapPasteCore
import XCTest

final class ImageClipboardTests: XCTestCase {
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

    private func png(_ width: Int = 64, _ height: Int = 32) throws -> URL {
        let url = temp.url.appendingPathComponent("\(UUID().uuidString).png")
        try TestImages.writePNG(width: width, height: height, to: url)
        return url
    }

    func testPNGBytesAreCopiedUnchanged() throws {
        let url = try png()
        try ImageClipboard(pasteboard: pasteboard).writePNG(at: url)
        XCTAssertEqual(pasteboard.data(forType: .png), try Data(contentsOf: url))
    }

    func testAdvertisesPNGAndTIFF() throws {
        try ImageClipboard(pasteboard: pasteboard).writePNG(at: try png())
        let types = try XCTUnwrap(pasteboard.types)
        XCTAssertTrue(types.contains(.png))
        XCTAssertTrue(types.contains(.tiff))
    }

    func testLazyTIFFHasSamePixelSize() throws {
        let clipboard = ImageClipboard(pasteboard: pasteboard)
        try clipboard.writePNG(at: try png(120, 45))
        let tiff = try XCTUnwrap(pasteboard.data(forType: .tiff))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        XCTAssertEqual(rep.pixelsWide, 120)
        XCTAssertEqual(rep.pixelsHigh, 45)
    }

    func testPasteReadersSeeAnImage() throws {
        try ImageClipboard(pasteboard: pasteboard).writePNG(at: try png(10, 12))
        XCTAssertTrue(pasteboard.canReadObject(forClasses: [NSImage.self], options: nil))
        let image = try XCTUnwrap(NSImage(pasteboard: pasteboard))
        XCTAssertEqual(image.representations.first?.pixelsWide, 10)
        XCTAssertEqual(image.representations.first?.pixelsHigh, 12)
    }

    func testReplacesPreviousClipboardContents() throws {
        pasteboard.clearContents()
        pasteboard.setString("eski metin", forType: .string)
        try ImageClipboard(pasteboard: pasteboard).writePNG(at: try png())
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
    }

    func testTIFFStillAvailableAfterFileIsDeleted() throws {
        let url = try png(33, 22)
        let clipboard = ImageClipboard(pasteboard: pasteboard)
        try clipboard.writePNG(at: url)
        try FileManager.default.removeItem(at: url)
        let rep = try XCTUnwrap(pasteboard.data(forType: .tiff).flatMap(NSBitmapImageRep.init(data:)))
        XCTAssertEqual(rep.pixelsWide, 33)
    }

    func testRejectsNonPNGAndLeavesClipboardAlone() throws {
        pasteboard.clearContents()
        pasteboard.setString("korunmalı", forType: .string)
        let url = temp.url.appendingPathComponent("fake.png")
        try Data("hello".utf8).write(to: url)

        XCTAssertThrowsError(try ImageClipboard(pasteboard: pasteboard).writePNG(at: url)) { error in
            XCTAssertEqual(error as? ClipboardError, .notPNG(url))
        }
        XCTAssertEqual(pasteboard.string(forType: .string), "korunmalı")
    }

    func testMissingFileThrows() {
        XCTAssertThrowsError(try ImageClipboard(pasteboard: pasteboard).writePNG(at: temp.url.appendingPathComponent("yok.png")))
    }
}
