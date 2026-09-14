import AppKit
import Carbon.HIToolbox

public struct HotKeyError: Error, Equatable {
    public let status: OSStatus
}

private let hotKeySignature: OSType = 0x534E_5053 // "SNPS"

/// System-wide hotkeys via Carbon's RegisterEventHotKey.
/// Unlike CGEventTap or NSEvent global monitors this needs no Accessibility /
/// Input Monitoring permission and costs nothing while idle: the window server
/// only wakes the app when the exact combination is pressed.
public final class HotKeyCenter {
    public static let shared = HotKeyCenter()

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    init() {}

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Registers `keyCode` + `modifiers` globally. Must be called on the main thread.
    @discardableResult
    public func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, handler: @escaping () -> Void) throws -> UInt32 {
        try installEventHandlerIfNeeded()
        let id = nextID
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            Self.carbonModifiers(from: modifiers),
            EventHotKeyID(signature: hotKeySignature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { throw HotKeyError(status: status) }
        nextID += 1
        refs[id] = ref
        handlers[id] = handler
        return id
    }

    public func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers.removeValue(forKey: id)
    }

    public func unregisterAll() {
        for id in Array(refs.keys) { unregister(id) }
    }

    @discardableResult
    func dispatch(id: UInt32) -> Bool {
        guard let handler = handlers[id] else { return false }
        handler()
        return true
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard status == noErr else { throw HotKeyError(status: status) }
    }
}

private func hotKeyEventHandler(_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else { return OSStatus(eventNotHandledErr) }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    return center.dispatch(id: hotKeyID.id) ? noErr : OSStatus(eventNotHandledErr)
}
