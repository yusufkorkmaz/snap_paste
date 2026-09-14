import AppKit
import Carbon.HIToolbox
@testable import SnapPasteCore
import XCTest

final class HotKeyTests: XCTestCase {
    // An obscure combination so the test never collides with the installed app or the system.
    private let testKey = UInt32(kVK_F19)
    private let testModifiers: NSEvent.ModifierFlags = [.control, .option, .command, .shift]

    func testShiftOptionMapsToCarbonFlags() {
        XCTAssertEqual(HotKeyCenter.carbonModifiers(from: [.shift, .option]), UInt32(shiftKey | optionKey))
    }

    func testAllModifiersMapToCarbonFlags() {
        XCTAssertEqual(
            HotKeyCenter.carbonModifiers(from: [.command, .option, .control, .shift]),
            UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )
        XCTAssertEqual(HotKeyCenter.carbonModifiers(from: []), 0)
    }

    func testDeviceSpecificFlagsAreIgnored() {
        XCTAssertEqual(HotKeyCenter.carbonModifiers(from: [.shift, .capsLock, .function]), UInt32(shiftKey))
    }

    func testRegisterUnregisterAndRegisterAgain() throws {
        let center = HotKeyCenter()
        let id = try center.register(keyCode: testKey, modifiers: testModifiers) {}
        center.unregister(id)
        let again = try center.register(keyCode: testKey, modifiers: testModifiers) {}
        XCTAssertNotEqual(id, again)
        center.unregister(again)
    }

    func testDuplicateRegistrationIsRejected() throws {
        let center = HotKeyCenter()
        let id = try center.register(keyCode: testKey, modifiers: testModifiers) {}
        defer { center.unregister(id) }
        XCTAssertThrowsError(try center.register(keyCode: testKey, modifiers: testModifiers) {}) { error in
            XCTAssertEqual(error as? HotKeyError, HotKeyError(status: OSStatus(eventHotKeyExistsErr)))
        }
    }

    func testDispatchCallsOnlyTheMatchingHandler() throws {
        let center = HotKeyCenter()
        var fired: [String] = []
        let first = try center.register(keyCode: testKey, modifiers: testModifiers) { fired.append("first") }
        let second = try center.register(keyCode: UInt32(kVK_F18), modifiers: testModifiers) { fired.append("second") }
        defer { center.unregisterAll() }

        XCTAssertTrue(center.dispatch(id: second))
        XCTAssertTrue(center.dispatch(id: first))
        XCTAssertEqual(fired, ["second", "first"])
    }

    func testDispatchAfterUnregisterDoesNothing() throws {
        let center = HotKeyCenter()
        var fired = false
        let id = try center.register(keyCode: testKey, modifiers: testModifiers) { fired = true }
        center.unregister(id)
        XCTAssertFalse(center.dispatch(id: id))
        XCTAssertFalse(fired)
    }

    func testRealHotKeyEventReachesHandler() throws {
        let center = HotKeyCenter()
        var fired = false
        let id = try center.register(keyCode: testKey, modifiers: testModifiers) { fired = true }
        defer { center.unregister(id) }

        // Deliver a genuine Carbon hot-key event through the application event target,
        // exercising the C callback, parameter extraction and signature check.
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeNone), &event), noErr)
        var hotKeyID = EventHotKeyID(signature: 0x534E_5053, id: id)
        XCTAssertEqual(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &hotKeyID), noErr)
        XCTAssertEqual(SendEventToEventTarget(event, GetApplicationEventTarget()), noErr)
        ReleaseEvent(event)
        XCTAssertTrue(fired)
    }

    func testForeignSignatureIsNotHandled() throws {
        let center = HotKeyCenter()
        var fired = false
        let id = try center.register(keyCode: testKey, modifiers: testModifiers) { fired = true }
        defer { center.unregister(id) }

        var event: EventRef?
        CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeNone), &event)
        var hotKeyID = EventHotKeyID(signature: 0x4F54_4852, id: id) // "OTHR"
        SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &hotKeyID)
        XCTAssertEqual(SendEventToEventTarget(event, GetApplicationEventTarget()), OSStatus(eventNotHandledErr))
        ReleaseEvent(event)
        XCTAssertFalse(fired)
    }
}
