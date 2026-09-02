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
    public private(set) var activeShortcut: HotkeyShortcut = HotkeyShortcut.defaultShortcut

    private init() {}

    public func register(
        shortcut: HotkeyShortcut? = nil,
        action: @escaping () -> Void
    ) {
        let targetShortcut = shortcut ?? PreferencesService.shared.shortcut
        unregister()
        self.onHotkeyPressed = action
        self.activeShortcut = targetShortcut

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

        // 2. Register specific hotkey
        let hotKeyID = EventHotKeyID(signature: 0x434C4950 /* 'CLIP' */, id: 1)
        let registerStatus = RegisterEventHotKey(
            targetShortcut.keyCode,
            targetShortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            print("[HotkeyManager] Failed to register hotkey \(targetShortcut.displayString): \(registerStatus)")
        } else {
            print("[HotkeyManager] Registered global hotkey [\(targetShortcut.displayString)] successfully")
        }
    }

    public func updateShortcut(_ shortcut: HotkeyShortcut) {
        guard let action = onHotkeyPressed else { return }
        register(shortcut: shortcut, action: action)
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
        // Note: deinit may run off-MainActor; Carbon APIs are thread-safe for cleanup.
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }
}
