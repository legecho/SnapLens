import Cocoa
import Carbon.HIToolbox

final class HotKeyManager {
    static let shared = HotKeyManager()
    static let hotKeyTriggeredNotification = Notification.Name("HotKeyTriggered")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private let defaultHotKeyID = EventHotKeyID(signature: 0x4954_4854, id: 1)

    private init() {}

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard status == noErr else {
            print("Failed to install hotkey event handler: \(status)")
            return
        }

        let ctrlKey = UInt32(controlKey) << 8
        let cmdKey = UInt32(cmdKey) << 8
        let modifiers = ctrlKey | cmdKey

        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            modifiers,
            defaultHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    fileprivate func handleHotKeyPressed() {
        NotificationCenter.default.post(name: HotKeyManager.hotKeyTriggeredNotification, object: nil)
    }
}

private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKeyPressed()
    return noErr
}
