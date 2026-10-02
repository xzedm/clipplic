//
//  MenuBarControlsView.swift
//  clipplic
//

import SwiftUI

struct MenuBarControlsView: View {
    @Environment(ClipboardManager.self) private var manager
    private let preferences = PreferencesService.shared

    var body: some View {
        Text(manager.isMonitoring ? "Clipboard capture is active" : "Clipboard capture is paused")
        Text("\(manager.items.count) items in history · \(manager.pinnedCount) pinned")

        Divider()

        Button {
            manager.toggleMonitoring()
        } label: {
            Label(manager.isMonitoring ? "Pause Clipboard Capture" : "Resume Clipboard Capture", systemImage: manager.isMonitoring ? "pause.circle" : "play.circle")
        }

        Toggle("Copy Screenshots Automatically", isOn: Bindable(preferences).autoCopyScreenshots)

        Divider()

        Button {
            FloatingPanelController.shared.hide()
            SettingsWindowController.shared.show()
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            FloatingPanelController.shared.hide()
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Clipplic"])
        } label: {
            Label("About Clipplic", systemImage: "info.circle")
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit Clipplic", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
