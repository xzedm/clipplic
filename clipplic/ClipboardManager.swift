//
//  ClipboardManager.swift
//  clipplic
//

import AppKit
import Foundation
import Observation

@Observable
@MainActor
public final class ClipboardManager {
    public static let shared = ClipboardManager()

    public var items: [ClipboardItem] = []
    public var searchText: String = ""
    public var selectedTypeFilter: ItemContentType? = nil
    public var isMonitoring: Bool = true
    public var maxHistoryLimit: Int = 500

    private let monitor: ClipboardMonitor
    public let storage: StorageService
    private var saveTask: Task<Void, Never>?
    private var pruneTimer: Timer?

    public init() {
        let defaultStorage = StorageService()
        self.storage = defaultStorage
        self.monitor = ClipboardMonitor()
        self.items = defaultStorage.load()
        pruneExpiredItems()
        setupMonitoring()
    }

    public init(storage: StorageService) {
        self.storage = storage
        self.monitor = ClipboardMonitor()
        self.items = storage.load()
        pruneExpiredItems()
        setupMonitoring()
    }

    private func setupMonitoring() {
        monitor.onItemCopied = { [weak self] newItem, imageData in
            Task { @MainActor [weak self] in
                self?.handleNewCopiedItem(newItem, imageData: imageData)
            }
        }

        ScreenshotWatcher.shared.onScreenshotCaptured = { [weak self] newItem, imageData in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleNewCopiedItem(newItem, imageData: imageData)
                if PreferencesService.shared.autoCopyScreenshots {
                    self.copyToClipboard(newItem, updateTimestamp: false)
                }
            }
        }

        if isMonitoring {
            monitor.start()
            ScreenshotWatcher.shared.start()
        }
        startPeriodicPruning()
    }

    public var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty && selectedTypeFilter == nil {
            return items
        }

        return items.filter { item in
            // Filter by content type if selected
            if let selectedType = selectedTypeFilter, item.contentType != selectedType {
                return false
            }

            // Filter by search query
            if !query.isEmpty {
                if let text = item.textContent, text.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if let app = item.sourceAppName, app.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if let files = item.filePaths, files.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
                    return true
                }
                return false
            }

            return true
        }
    }

    public var pinnedCount: Int {
        items.filter { $0.isPinned }.count
    }

    public var imagesCount: Int {
        items.filter { $0.contentType == .image }.count
    }

    public var filesCount: Int {
        items.filter { $0.contentType == .file }.count
    }

    public func handleNewCopiedItem(_ newItem: ClipboardItem, imageData: Data?) {
        let existingIndex = items.firstIndex(where: { $0.contentHash == newItem.contentHash })

        // Save image only when it isn't already stored (duplicates would leave orphan files on disk)
        if let data = imageData, newItem.contentType == .image,
           existingIndex.flatMap({ items[$0].imageFileName }) == nil {
            _ = storage.saveImageData(data, id: newItem.id)
        }

        // Deduplicate using contentHash
        if let existingIndex {
            let existingItem = items.remove(at: existingIndex)

            let updated = ClipboardItem(
                id: existingItem.id,
                contentType: newItem.contentType,
                textContent: newItem.textContent,
                rtfData: newItem.rtfData ?? existingItem.rtfData,
                imageFileName: existingItem.imageFileName ?? newItem.imageFileName,
                imageWidth: newItem.imageWidth ?? existingItem.imageWidth,
                imageHeight: newItem.imageHeight ?? existingItem.imageHeight,
                imageByteSize: newItem.imageByteSize ?? existingItem.imageByteSize,
                filePaths: newItem.filePaths ?? existingItem.filePaths,
                createdAt: Date(),
                isPinned: existingItem.isPinned,
                isSensitive: newItem.isSensitive || existingItem.isSensitive,
                sourceAppName: newItem.sourceAppName ?? existingItem.sourceAppName,
                sourceAppBundleID: newItem.sourceAppBundleID ?? existingItem.sourceAppBundleID,
                contentHash: newItem.contentHash
            )
            items.insert(updated, at: 0)
        } else {
            items.insert(newItem, at: 0)
        }

        enforceHistoryLimit()
        scheduleSave()
    }

    public func copyToClipboard(_ item: ClipboardItem, updateTimestamp: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .image:
            let pbItem = NSPasteboardItem()

            // 1. PNG data representation (universal for Web, Slack, Discord, Chrome, Figma, Electron)
            var pngData: Data? = nil
            if let fileName = item.imageFileName {
                let imgURL = storage.imageURL(for: fileName)
                pngData = try? Data(contentsOf: imgURL)
            }
            if pngData == nil, let filePath = item.filePaths?.first {
                pngData = try? Data(contentsOf: URL(fileURLWithPath: filePath))
            }
            if let pngData {
                pbItem.setData(pngData, forType: .png)
            }

            // 2. TIFF representation (for native AppKit applications)
            var tiffData: Data? = nil
            if let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
                tiffData = image.tiffRepresentation
            } else if let filePath = item.filePaths?.first, let image = NSImage(contentsOfFile: filePath) {
                tiffData = image.tiffRepresentation
            }
            if let tiffData {
                pbItem.setData(tiffData, forType: .tiff)
            }

            // 3. File URL representation (for Finder, Telegram, Messages, AirDrop)
            if let filePath = item.filePaths?.first, FileManager.default.fileExists(atPath: filePath) {
                let fileURL = URL(fileURLWithPath: filePath)
                pbItem.setString(fileURL.absoluteString, forType: .fileURL)
            }

            pasteboard.writeObjects([pbItem])

        case .file:
            if let filePaths = item.filePaths {
                let fileURLs = filePaths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(fileURLs)
            }

        case .text, .code, .url, .rtf:
            let pasteboardItem = NSPasteboardItem()
            if let rtf = item.rtfData {
                pasteboardItem.setData(rtf, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboardItem.setString(text, forType: .string)
            }
            if item.isSensitive {
                // Tell other clipboard managers / Universal Clipboard not to record this secret
                pasteboardItem.setString("", forType: .init("org.nspasteboard.ConcealedType"))
            }
            pasteboard.writeObjects([pasteboardItem])
        }

        // Tell monitor to ignore our own pasteboard write
        monitor.ignoreCurrentChangeCount()

        // Move the item to top as recently used (if requested)
        guard updateTimestamp else { return }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let existing = items.remove(at: index)
            let refreshed = ClipboardItem(
                id: existing.id,
                contentType: existing.contentType,
                textContent: existing.textContent,
                rtfData: existing.rtfData,
                imageFileName: existing.imageFileName,
                imageWidth: existing.imageWidth,
                imageHeight: existing.imageHeight,
                imageByteSize: existing.imageByteSize,
                filePaths: existing.filePaths,
                createdAt: Date(),
                isPinned: existing.isPinned,
                isSensitive: existing.isSensitive,
                sourceAppName: existing.sourceAppName,
                sourceAppBundleID: existing.sourceAppBundleID,
                contentHash: existing.contentHash
            )
            items.insert(refreshed, at: 0)
            scheduleSave()
        }
    }

    public func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        storage.save(items: items)
    }

    public func deleteItem(_ item: ClipboardItem) {
        if let fileName = item.imageFileName {
            storage.deleteImage(for: fileName)
        }
        items.removeAll { $0.id == item.id }
        storage.save(items: items)
    }

    public func clearHistory(includingPinned: Bool = false) {
        if includingPinned {
            items.removeAll()
            storage.clear()
        } else {
            let unpinnedImages = items.filter { !$0.isPinned }.compactMap { $0.imageFileName }
            for fileName in unpinnedImages {
                storage.deleteImage(for: fileName)
            }
            items.removeAll { !$0.isPinned }
            storage.save(items: items)
        }
    }

    public func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            monitor.start()
            ScreenshotWatcher.shared.start()
        } else {
            monitor.stop()
            ScreenshotWatcher.shared.stop()
        }
    }
    public func pruneExpiredItems() {
        let retentionDays = PreferencesService.shared.retentionDays
        guard retentionDays > 0 else { return }

        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }

        let expiredUnpinned = items.filter { !$0.isPinned && $0.createdAt < cutoffDate }
        for item in expiredUnpinned {
            if let fileName = item.imageFileName {
                storage.deleteImage(for: fileName)
            }
        }

        items.removeAll { !$0.isPinned && $0.createdAt < cutoffDate }
        storage.save(items: items)
    }

    private func enforceHistoryLimit() {
        let limit = PreferencesService.shared.historyLimit
        guard items.count > limit else { return }

        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        let allowedUnpinned = max(0, limit - pinned.count)
        let trimmedUnpinned = Array(unpinned.prefix(allowedUnpinned))

        // Delete discarded unpinned images from disk
        if unpinned.count > allowedUnpinned {
            let dropped = unpinned.suffix(from: allowedUnpinned)
            for item in dropped {
                if let fileName = item.imageFileName {
                    storage.deleteImage(for: fileName)
                }
            }
        }

        items = (pinned + trimmedUnpinned).sorted { $0.createdAt > $1.createdAt }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, let self else { return }
            self.storage.save(items: self.items)
        }
    }

    /// Writes history immediately, cancelling any pending debounced save.
    public func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        storage.save(items: items)
    }

    private func startPeriodicPruning() {
        // Retention was only applied at launch; a menu bar app can run for weeks
        pruneTimer?.invalidate()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pruneExpiredItems()
            }
        }
    }
}
