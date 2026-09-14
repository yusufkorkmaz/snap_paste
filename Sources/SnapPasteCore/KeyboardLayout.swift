import Carbon.HIToolbox
import Foundation

/// Hotkeys are registered by virtual key code, which is a physical key position.
/// Resolving the code from the active layout makes ⇧⌥S follow the key labelled "S"
/// on Turkish-F, Dvorak, AZERTY… instead of the US-QWERTY position.
public enum KeyboardLayout {
    public static func currentKeyCode(for character: Character) -> UInt32? {
        if let code = keyCode(for: character, in: TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()) {
            return code
        }
        // Non-Latin layouts (e.g. Russian) have no "s"; shortcuts then use the ASCII-capable layout.
        return keyCode(for: character, in: TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue())
    }

    public static func inputSource(id: String) -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return list.first
    }

    public static func keyCode(for character: Character, in source: TISInputSource?) -> UInt32? {
        guard let source, let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return keyCode(for: character, layoutData: data)
    }

    static func keyCode(for character: Character, layoutData: Data) -> UInt32? {
        let target = String(character).lowercased()
        let keyboardType = UInt32(LMGetKbdType())
        return layoutData.withUnsafeBytes { buffer -> UInt32? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var chars = [UniChar](repeating: 0, count: 4)
            for keyCode in UInt16(0) ..< 128 {
                var deadKeyState: UInt32 = 0
                var length = 0
                let status = UCKeyTranslate(
                    layout,
                    keyCode,
                    UInt16(kUCKeyActionDown),
                    0,
                    keyboardType,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )
                if status == noErr, length > 0,
                   String(utf16CodeUnits: chars, count: length).lowercased() == target {
                    return UInt32(keyCode)
                }
            }
            return nil
        }
    }
}
