//
//  HotkeyManager.swift
//  clipplic
//

import AppKit
import Carbon

@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var onHotkeyPressed: (() -> Void)?

    private init() {}

    public func register(
        keyCode: UInt32 = UInt32(kVK_ANSI_V),
        modifiers: UInt32 = UInt32(cmdKey | shiftKey),
        action: @escaping () -> Void
    ) {
        unregister()
        self.onHotkeyPressed = action

        // 1. Install Carbon event handler for HotKey Pressed
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerBlock: EventHandlerUPP = { _, eventRef, _ in
            guard let eventRef = eventRef else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr && hotKeyID.signature == 0x434C4950 /* 'CLIP' */ {
                DispatchQueue.main.async {
                    HotkeyManager.shared.onHotkeyPressed?()
                }
            }
            return noErr
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            print("[HotkeyManager] Failed to install event handler: \(installStatus)")
            return
        }

        // 2. Register specific hotkey (⌘⇧V)
        let hotKeyID = EventHotKeyID(signature: 0x434C4950 /* 'CLIP' */, id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("[HotkeyManager] Failed to register hotkey: \(registerStatus)")
        } else {
            print("[HotkeyManager] Registered global hotkey ⌘⇧V successfully")
        }
    }

    public func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        // Safe cleanup if instance is deallocated
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
