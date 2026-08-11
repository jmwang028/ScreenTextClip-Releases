import Carbon
import Foundation

final class HotkeyManager {
    private static let signature = OSType(0x53544348) // STCH
    private static let hotKeyID = UInt32(1)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        stop()
    }

    func start() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            DebugLogger.log("InstallEventHandler failed status=\(handlerStatus)", category: "HotkeyManager")
            NotificationService.show(InterfaceText.localized("Hotkey unavailable", "快捷键不可用"))
            return
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            DebugLogger.log("RegisterEventHotKey failed status=\(hotKeyStatus)", category: "HotkeyManager")
            NotificationService.show(InterfaceText.localized("Hotkey unavailable", "快捷键不可用"))
            removeEventHandler()
            return
        }

        DebugLogger.log("registered Control+Command+S", category: "HotkeyManager")
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        removeEventHandler()
    }

    private func removeEventHandler() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }

        var eventHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventHotKeyID
        )

        guard status == noErr else { return status }
        guard eventHotKeyID.signature == HotkeyManager.signature,
              eventHotKeyID.id == HotkeyManager.hotKeyID else {
            return noErr
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        DispatchQueue.main.async {
            DebugLogger.log("hotkey pressed", category: "HotkeyManager")
            manager.onPressed()
        }

        return noErr
    }
}
