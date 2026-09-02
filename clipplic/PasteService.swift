//
//  PasteService.swift
//  clipplic
//

import AppKit
import ApplicationServices
import Foundation

@MainActor
public final class PasteService {
    public static let shared = PasteService()

    private var previousApp: NSRunningApplication?

    private init() {}

    public func recordFrontmostApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        // Only record if frontmost is not our own app
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.previousApp = frontmost
        }
    }

    public func restoreAndPaste(item: ClipboardItem, manager: ClipboardManager, autoPaste: Bool? = nil) {
        let shouldAutoPaste = autoPaste ?? PreferencesService.shared.autoPasteOnEnter

        // 1. Copy item to pasteboard
        manager.copyToClipboard(item)

        // 2. Hide HUD window
        FloatingPanelController.shared.hide()

        guard shouldAutoPaste, let targetApp = previousApp else { return }

        // Verify accessibility permission before attempting to simulate paste
        guard Self.isAccessibilityPermissionGranted else {
            Self.requestAccessibilityPermission()
            return
        }

        // 3. Reactivate target application
        targetApp.activate()

        // 4. Delay slightly to allow the target window to take focus, then post ⌘V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.simulatePasteCommand()
        }
    }

    public func simulatePasteCommand() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    public static var isAccessibilityPermissionGranted: Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
