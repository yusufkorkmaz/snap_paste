import Foundation

public final class Settings {
    enum Key {
        static let captureMode = "captureMode"
        static let playSound = "playSound"
        static let didOfferLoginItem = "didOfferLoginItem"
        static let didRequestScreenRecording = "didRequestScreenRecording"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.captureMode: CaptureMode.region.rawValue,
            Key.playSound: true,
        ])
    }

    public var captureMode: CaptureMode {
        get { defaults.string(forKey: Key.captureMode).flatMap(CaptureMode.init(rawValue:)) ?? .region }
        set { defaults.set(newValue.rawValue, forKey: Key.captureMode) }
    }

    public var playSound: Bool {
        get { defaults.bool(forKey: Key.playSound) }
        set { defaults.set(newValue, forKey: Key.playSound) }
    }

    public var didOfferLoginItem: Bool {
        get { defaults.bool(forKey: Key.didOfferLoginItem) }
        set { defaults.set(newValue, forKey: Key.didOfferLoginItem) }
    }

    public var didRequestScreenRecording: Bool {
        get { defaults.bool(forKey: Key.didRequestScreenRecording) }
        set { defaults.set(newValue, forKey: Key.didRequestScreenRecording) }
    }
}
