//
//  SettingsView.swift
//  clipplic
//

import AppKit
import ServiceManagement
import SwiftUI
struct SettingsView: View {
    @State private var prefs = PreferencesService.shared
    @Environment(ClipboardManager.self) private var manager
    @State private var selectedTab: SettingsTab = .general
    @State private var newCustomBundleId: String = ""
    @State private var showingCustomAppField: Bool = false
    @State private var imageCacheSize: Int64 = 0
    @State private var showingPurgeConfirm: Bool = false

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case privacy = "Privacy"
        case storage = "Storage"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .general:
                return "gearshape"
            case .privacy:
                return "hand.raised.fill"
            case .storage:
                return "internaldrive"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Tab Selector Bar
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 12))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // MARK: - Tab Body
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalTabContent
                    case .privacy:
                        privacyTabContent
                    case .storage:
                        storageTabContent
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 440)
        .onAppear {
            refreshCacheSize()
        }
    }

    // MARK: - General Tab
    private var generalTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // System Startup
            GroupBox(label: Label("System Startup", systemImage: "macwindow")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch Clipplic automatically at login", isOn: $prefs.isLaunchAtLoginEnabled)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 13))

                    Text("Clipplic will start silently in the menu bar on system boot.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(6)
            }

            // Keyboard Shortcuts
            GroupBox(label: Label("Global Shortcut", systemImage: "keyboard")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open Clipboard History HUD:")
                                .font(.system(size: 13, weight: .medium))
                            Text("Click to record a new global shortcut")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ShortcutRecorderView()
                    }

                    Toggle("Auto-paste on Enter", isOn: $prefs.autoPasteOnEnter)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 13))

                    Text("When enabled, pressing Enter automatically pastes the selected item directly into your active window.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(6)
            }

            // Monitoring Status
            GroupBox(label: Label("Clipboard Observer", systemImage: "clipboard")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.isMonitoring ? "Monitoring is Active" : "Monitoring is Paused")
                            .font(.system(size: 13, weight: .medium))
                        Text(manager.isMonitoring ? "Clipplic is capturing new text, images, and files." : "New clipboard copies will not be recorded.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(manager.isMonitoring ? "Pause" : "Resume") {
                        manager.toggleMonitoring()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.isMonitoring ? .orange : .accentColor)
                }
                .padding(6)
            }
        }
    }

    // MARK: - Privacy Tab
    private var privacyTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Password & Credential Capture
            GroupBox(label: Label("Passwords & Sensitive Credentials", systemImage: "key.fill")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Filter Passwords & Password Managers (Recommended)", isOn: $prefs.filterPasswordManagers)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 13, weight: .medium))

                    if prefs.filterPasswordManagers {
                        Text("✓ 1Password, Bitwarden, Keychain, KeePassXC, and concealed tokens are automatically blocked from history.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("Password capture is enabled. Passwords and credentials copied to the clipboard will be recorded in your local history.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }

                            Divider()
                                .opacity(0.3)

                            Toggle("Mask sensitive passwords in history list (••••••••••••)", isOn: $prefs.maskPasswordsInList)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }
                }
                .padding(6)
            }
            // Ignored Applications
            GroupBox(label: Label("Ignored Applications", systemImage: "app.badge.xmark")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Clipboard copies from these applications will never be stored in history:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // Apps List
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(prefs.ignoredBundleIDs, id: \.self) { bundleId in
                                HStack {
                                    if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                            .resizable()
                                            .frame(width: 18, height: 18)
                                    } else {
                                        Image(systemName: "app.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(displayName(for: bundleId))
                                            .font(.system(size: 12, weight: .medium))
                                        Text(bundleId)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Button {
                                        prefs.removeIgnoredApp(bundleID: bundleId)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(height: 140)

                    // Add App Controls
                    HStack(spacing: 8) {
                        Menu("Add Running App...") {
                            let running = NSWorkspace.shared.runningApplications
                                .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
                            ForEach(running, id: \.bundleIdentifier) { app in
                                if let id = app.bundleIdentifier, !prefs.ignoredBundleIDs.contains(id) {
                                    Button(app.localizedName ?? id) {
                                        prefs.addIgnoredApp(bundleID: id)
                                    }
                                }
                            }
                        }
                        .menuStyle(.borderedButton)

                        Button("Custom Bundle ID") {
                            showingCustomAppField.toggle()
                        }
                        .buttonStyle(.bordered)
                    }

                    if showingCustomAppField {
                        HStack {
                            TextField("e.g. com.googlecode.iterm2", text: $newCustomBundleId)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))

                            Button("Add") {
                                let trimmed = newCustomBundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    prefs.addIgnoredApp(bundleID: trimmed)
                                    newCustomBundleId = ""
                                    showingCustomAppField = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - Storage Tab
    private var storageTabContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Retention Rules
            GroupBox(label: Label("Retention & Limits", systemImage: "clock.arrow.circlepath")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Maximum History Items:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $prefs.historyLimit) {
                            Text("100 items").tag(100)
                            Text("300 items").tag(300)
                            Text("500 items").tag(500)
                            Text("1,000 items").tag(1000)
                            Text("5,000 items").tag(5000)
                        }
                        .frame(width: 140)
                    }

                    HStack {
                        Text("Auto-delete items older than:")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $prefs.retentionDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("1 year").tag(365)
                            Text("Never").tag(0)
                        }
                        .frame(width: 140)
                    }

                    Text("Pinned items are permanent and will never be auto-deleted.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(6)
            }

            // Disk Storage Usage
            GroupBox(label: Label("Disk Storage", systemImage: "internaldrive")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("History Data: \(manager.items.count) items (\(manager.pinnedCount) pinned)")
                                .font(.system(size: 12, weight: .medium))
                            Text("Image Cache: \(ByteCountFormatter.string(fromByteCount: imageCacheSize, countStyle: .file)) on disk")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Refresh") {
                            refreshCacheSize()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    HStack {
                        Button("Clear Unpinned History") {
                            showingPurgeConfirm = true
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button("Open Storage Folder") {
                            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                            if let dir = appSupport?.appendingPathComponent("clipplic") {
                                NSWorkspace.shared.open(dir)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(6)
            }
        }
        .confirmationDialog(
            "Clear unpinned history items and cached images?",
            isPresented: $showingPurgeConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Unpinned History", role: .destructive) {
                manager.clearHistory(includingPinned: false)
                refreshCacheSize()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func refreshCacheSize() {
        imageCacheSize = prefs.calculateImageCacheSize()
    }

    private func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName ?? url.deletingPathExtension().lastPathComponent
        }
        return bundleID.components(separatedBy: ".").last?.capitalized ?? bundleID
    }
}
