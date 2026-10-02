//
//  clipplicApp.swift
//  clipplic
//

import SwiftUI

@main
struct clipplicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarControlsView()
                .environment(ClipboardManager.shared)
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel("Clipplic controls")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(ClipboardManager.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 0. Keep the app alive. SwiftUI apps opt into Automatic/Sudden Termination by default,
        // so macOS silently quits a windowless menu bar app when it looks idle
        // (no crash report is written). A clipboard manager must stay running.
        ProcessInfo.processInfo.disableAutomaticTermination("Clipplic monitors the clipboard in the background")
        ProcessInfo.processInfo.disableSuddenTermination()

        // 1. Setup Floating Spotlight HUD with the shared manager
        FloatingPanelController.shared.setup(
            rootView: FloatingHUDView()
                .environment(ClipboardManager.shared),
            width: FloatingHUDView.panelWidth,
            height: FloatingHUDView.panelHeight
        )

        // 2. Register Global Hotkey (⌘⇧V)
        HotkeyManager.shared.register {
            PasteService.shared.recordFrontmostApp()
            FloatingPanelController.shared.toggle()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Closing Settings or the HUD must never quit the menu bar app
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush any debounced save so the latest copies are not lost on quit
        ClipboardManager.shared.saveNow()
    }
}
