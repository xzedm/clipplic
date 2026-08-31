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
    private let kAutoPasteOnEnter = "clipplic_auto_paste_on_enter"

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

    public var autoPasteOnEnter: Bool {
        didSet {
            defaults.set(autoPasteOnEnter, forKey: kAutoPasteOnEnter)
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
        // Default sensitive app identifiers
        let defaultIgnored = [
            "com.agilebits.onepassword",
            "com.agilebits.onepassword7",
            "com.1password.1password",
            "com.bitwarden.desktop",
            "org.keepassxc.keepassxc",
            "com.apple.keychainaccess"
        ]

        if let saved = defaults.stringArray(forKey: kIgnoredBundleIDs) {
            self.ignoredBundleIDs = saved
        } else {
            self.ignoredBundleIDs = defaultIgnored
            defaults.set(defaultIgnored, forKey: kIgnoredBundleIDs)
        }

        let savedLimit = defaults.integer(forKey: kHistoryLimit)
        self.historyLimit = (savedLimit > 0) ? savedLimit : 500

        let savedRetention = defaults.integer(forKey: kRetentionDays)
        self.retentionDays = (savedRetention != 0) ? savedRetention : 30

        if defaults.object(forKey: kFilterPasswordManagers) != nil {
            self.filterPasswordManagers = defaults.bool(forKey: kFilterPasswordManagers)
        } else {
            self.filterPasswordManagers = true
        }

        if defaults.object(forKey: kAutoPasteOnEnter) != nil {
            self.autoPasteOnEnter = defaults.bool(forKey: kAutoPasteOnEnter)
        } else {
            self.autoPasteOnEnter = true
        }
    }

    public func isAppIgnored(bundleID: String?) -> Bool {
        guard let id = bundleID?.lowercased() else { return false }
        return ignoredBundleIDs.contains { $0.lowercased() == id }
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
