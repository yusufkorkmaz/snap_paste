import CoreGraphics
import Foundation

public enum CaptureMode: String, CaseIterable {
    case region
    case window
    case fullScreen
}

/// Builds invocations of macOS's own `screencapture` tool, which provides the native
/// crosshair / window-picker UI with no extra code or memory in this app.
public enum CaptureCommand {
    public static let executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

    public static func arguments(mode: CaptureMode, playSound: Bool, displayNumber: Int? = nil, output: URL) -> [String] {
        var args: [String]
        switch mode {
        case .region:
            args = ["-i"] // drag to select; Space toggles window picking, Esc cancels
        case .window:
            args = ["-i", "-W"]
        case .fullScreen:
            args = displayNumber.map { ["-D", String($0)] } ?? ["-m"]
        }
        if !playSound { args.append("-x") }
        args += ["-t", "png", output.path]
        return args
    }

    /// `screencapture -D` numbers displays 1…n in CGGetActiveDisplayList order (main display first).
    public static func displayNumber(containing point: CGPoint, displayBounds: [CGRect]) -> Int? {
        displayBounds.firstIndex { $0.contains(point) }.map { $0 + 1 }
    }

    public static func displayNumberUnderMouse() -> Int? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return nil }
        return displayNumber(containing: location, displayBounds: ids.prefix(Int(count)).map(CGDisplayBounds))
    }
}
