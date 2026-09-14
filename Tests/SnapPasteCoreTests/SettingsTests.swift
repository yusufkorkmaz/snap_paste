@testable import SnapPasteCore
import XCTest

final class SettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "SnapPasteTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() {
        let settings = Settings(defaults: defaults)
        XCTAssertEqual(settings.captureMode, .region)
        XCTAssertTrue(settings.playSound)
        XCTAssertFalse(settings.didOfferLoginItem)
        XCTAssertFalse(settings.didRequestScreenRecording)
    }

    func testValuesPersistAcrossInstances() {
        let settings = Settings(defaults: defaults)
        settings.captureMode = .fullScreen
        settings.playSound = false
        settings.didOfferLoginItem = true
        settings.didRequestScreenRecording = true

        let reloaded = Settings(defaults: UserDefaults(suiteName: suiteName)!)
        XCTAssertEqual(reloaded.captureMode, .fullScreen)
        XCTAssertFalse(reloaded.playSound)
        XCTAssertTrue(reloaded.didOfferLoginItem)
        XCTAssertTrue(reloaded.didRequestScreenRecording)
    }

    func testUnknownStoredModeFallsBackToRegion() {
        defaults.set("hologram", forKey: Settings.Key.captureMode)
        XCTAssertEqual(Settings(defaults: defaults).captureMode, .region)
    }
}
