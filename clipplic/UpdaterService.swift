//
//  UpdaterService.swift
//  clipplic
//

import Foundation
import Observation
import Sparkle

/// Automatic updates through Sparkle. Reads the feed URL and signing key from Info.plist (Config/Info.plist).
@Observable
@MainActor
public final class UpdaterService {
    public static let shared = UpdaterService()

    /// False until a real Sparkle public key is in Info.plist, so a build without one never shows update errors.
    public let isConfigured: Bool
    public private(set) var canCheckForUpdates = false

    private let controller: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    private init() {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isConfigured = !key.isEmpty && !key.hasPrefix("REPLACE_")

        guard isConfigured else {
            controller = nil
            print("[UpdaterService] Sparkle public key missing; automatic updates are off")
            return
        }

        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in self?.canCheckForUpdates = canCheck }
        }
    }

    /// Starts the updater. Call once at launch.
    public func start() {
        _ = controller
    }

    public func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    public var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller?.updater.automaticallyChecksForUpdates ?? false
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller?.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    public var currentVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
