import Carbon.HIToolbox
@testable import SnapPasteCore
import XCTest

final class KeyboardLayoutTests: XCTestCase {
    private func keyCode(_ character: Character, layout id: String) throws -> UInt32? {
        let source = try XCTUnwrap(KeyboardLayout.inputSource(id: id), "\(id) layout not installed")
        return KeyboardLayout.keyCode(for: character, in: source)
    }

    func testCurrentLayoutResolvesS() {
        XCTAssertNotNil(KeyboardLayout.currentKeyCode(for: "s"))
    }

    func testUSLayoutUsesANSIPosition() throws {
        XCTAssertEqual(try keyCode("s", layout: "com.apple.keylayout.US"), UInt32(kVK_ANSI_S))
    }

    func testTurkishQUsesANSIPosition() throws {
        XCTAssertEqual(try keyCode("s", layout: "com.apple.keylayout.Turkish-QWERTY-PC"), UInt32(kVK_ANSI_S))
    }

    func testTurkishFFollowsTheKeyLabelledS() throws {
        // Turkish-F bottom row is "j ö v c ç z s b": S sits where ANSI has M.
        XCTAssertEqual(try keyCode("s", layout: "com.apple.keylayout.Turkish-Standard"), UInt32(kVK_ANSI_M))
    }

    func testDvorakFollowsTheKeyLabelledS() throws {
        // Dvorak home row "a o e u i d h t n s": S sits where ANSI has semicolon.
        XCTAssertEqual(try keyCode("s", layout: "com.apple.keylayout.Dvorak"), UInt32(kVK_ANSI_Semicolon))
    }

    func testUppercaseInputMatchesSameKey() throws {
        XCTAssertEqual(try keyCode("S", layout: "com.apple.keylayout.US"), UInt32(kVK_ANSI_S))
    }

    func testCharacterWithoutKeyReturnsNil() throws {
        XCTAssertNil(try keyCode("😀", layout: "com.apple.keylayout.US"))
    }

    func testMissingSourceReturnsNil() {
        XCTAssertNil(KeyboardLayout.keyCode(for: "s", in: nil))
        XCTAssertNil(KeyboardLayout.inputSource(id: "com.example.does-not-exist"))
    }
}
