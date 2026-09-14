//
//  PreferencesService.swift
//  clipplic
//

import AppKit
import Foundation
import Observation
import ServiceManagement

@Observable
@MainActor
public final class PreferencesService {
    public static let shared = PreferencesService()

    private let defaults = UserDefaults.standard

    // Keys
    private let kIgnoredBundleIDs = "clipplic_ignored_bundle_ids"
    private let kHistoryLimit = "clipplic_history_limit"
    private let kRetentionDays = "clipplic_retention_days"
    private let kFilterPasswordManagers = "clipplic_filter_password_managers"
    private let kMaskPasswordsInList = "clipplic_mask_passwords_in_list"
    private let kAutoPasteOnEnter = "clipplic_auto_paste_on_enter"
    private let kHotkeyKeyCode = "clipplic_hotkey_key_code"
    private let kHotkeyModifiers = "clipplic_hotkey_modifiers"
    private let kAutoCopyScreenshots = "clipplic_auto_copy_screenshots"
    private let kInstantScreenshots = "clipplic_instant_screenshots"
    public static let knownPasswordManagerBundleIDs: [String] = [
        "com.agilebits.onepassword",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.apple.keychainaccess"
    ]

    public var ignoredBundleIDs: [String] {
        didSet {
            defaults.set(ignoredBundleIDs, forKey: kIgnoredBundleIDs)
        }
    }

    public var historyLimit: Int {
        didSet {
            defaults.set(historyLimit, forKey: kHistoryLimit)
        }
    }

    public var retentionDays: Int {
        didSet {
            defaults.set(retentionDays, forKey: kRetentionDays)
        }
    }

    public var filterPasswordManagers: Bool {
        didSet {
            defaults.set(filterPasswordManagers, forKey: kFilterPasswordManagers)
        }
    }

    public var maskPasswordsInList: Bool {
        didSet {
            defaults.set(maskPasswordsInList, forKey: kMaskPasswordsInList)
        }
    }

    public var autoPasteOnEnter: Bool {
        didSet {
            defaults.set(autoPasteOnEnter, forKey: kAutoPasteOnEnter)
        }
    }

    public var autoCopyScreenshots: Bool {
        didSet {
            defaults.set(autoCopyScreenshots, forKey: kAutoCopyScreenshots)
        }
    }

    public var instantScreenshots: Bool {
        didSet {
            defaults.set(instantScreenshots, forKey: kInstantScreenshots)
            applyInstantScreenshots(instantScreenshots)
        }
    }

    public var shortcut: HotkeyShortcut {
        didSet {
            defaults.set(shortcut.keyCode, forKey: kHotkeyKeyCode)
            defaults.set(shortcut.modifiers, forKey: kHotkeyModifiers)
            HotkeyManager.shared.updateShortcut(shortcut)
        }
    }


    public var isLaunchAtLoginEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            setLaunchAtLogin(newValue)
        }
    }

    private init() {
        if let saved = defaults.stringArray(forKey: kIgnoredBundleIDs) {
            self.ignoredBundleIDs = saved
        } else {
            self.ignoredBundleIDs = []
            defaults.set([], forKey: kIgnoredBundleIDs)
        }

        let savedLimit = defaults.integer(forKey: kHistoryLimit)
        self.historyLimit = (savedLimit > 0) ? savedLimit : 500

        let savedRetention = defaults.integer(forKey: kRetentionDays)
        self.retentionDays = (savedRetention > 0) ? savedRetention : 30

        if defaults.object(forKey: kFilterPasswordManagers) != nil {
            self.filterPasswordManagers = defaults.bool(forKey: kFilterPasswordManagers)
        } else {
            self.filterPasswordManagers = true
        }

        if defaults.object(forKey: kMaskPasswordsInList) != nil {
            self.maskPasswordsInList = defaults.bool(forKey: kMaskPasswordsInList)
        } else {
            self.maskPasswordsInList = true
        }

        if defaults.object(forKey: kAutoPasteOnEnter) != nil {
            self.autoPasteOnEnter = defaults.bool(forKey: kAutoPasteOnEnter)
        } else {
            self.autoPasteOnEnter = true
        }

        if defaults.object(forKey: kAutoCopyScreenshots) != nil {
            self.autoCopyScreenshots = defaults.bool(forKey: kAutoCopyScreenshots)
        } else {
            self.autoCopyScreenshots = true
        }

        let screencaptureThumbnail = UserDefaults(suiteName: "com.apple.screencapture")?.bool(forKey: "show-thumbnail") ?? true
        if defaults.object(forKey: kInstantScreenshots) != nil {
            self.instantScreenshots = defaults.bool(forKey: kInstantScreenshots)
        } else {
            self.instantScreenshots = !screencaptureThumbnail
        }

        let savedKeyCode = UInt32(defaults.integer(forKey: kHotkeyKeyCode))
        let savedModifiers = UInt32(defaults.integer(forKey: kHotkeyModifiers))
        if savedKeyCode != 0 && savedModifiers != 0 {
            self.shortcut = HotkeyShortcut(keyCode: savedKeyCode, modifiers: savedModifiers)
        } else {
            self.shortcut = HotkeyShortcut.defaultShortcut
        }
    }

    public func isAppIgnored(bundleID: String?) -> Bool {
        guard let id = bundleID?.lowercased() else { return false }

        // 1. User custom ignored apps are always blocked
        if ignoredBundleIDs.contains(where: { $0.lowercased() == id }) {
            return true
        }

        // 2. Password managers blocked only if filterPasswordManagers is true
        if filterPasswordManagers {
            if Self.knownPasswordManagerBundleIDs.contains(where: { $0.lowercased() == id }) {
                return true
            }
        }

        return false
    }

    public func isPasswordManager(bundleID: String?) -> Bool {
        guard let id = bundleID?.lowercased() else { return false }
        return Self.knownPasswordManagerBundleIDs.contains { $0.lowercased() == id }
    }

    public func addIgnoredApp(bundleID: String) {
        if !ignoredBundleIDs.contains(bundleID) {
            ignoredBundleIDs.append(bundleID)
        }
    }

    public func removeIgnoredApp(bundleID: String) {
        ignoredBundleIDs.removeAll { $0 == bundleID }
    }

    public func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("[PreferencesService] Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    public func applyInstantScreenshots(_ enable: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        if enable {
            task.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", "false"]
        } else {
            task.arguments = ["delete", "com.apple.screencapture", "show-thumbnail"]
        }
        try? task.run()
    }

    public func calculateImageCacheSize() -> Int64 {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let imagesDir = appSupport.appendingPathComponent("clipplic/images", isDirectory: true)

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            let path = imagesDir.appendingPathComponent(file).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
}
