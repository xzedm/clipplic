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
            ContentView()
                .environment(ClipboardManager.shared)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(ClipboardManager.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Setup Floating Spotlight HUD with the shared manager
        FloatingPanelController.shared.setup(
            rootView: FloatingHUDView()
                .environment(ClipboardManager.shared)
        )

        // 2. Register Global Hotkey (⌘⇧V)
        HotkeyManager.shared.register {
            PasteService.shared.recordFrontmostApp()
            FloatingPanelController.shared.toggle()
        }
    }
}
