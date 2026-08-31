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

    public init() {
        let defaultStorage = StorageService()
        self.storage = defaultStorage
        self.monitor = ClipboardMonitor()
        self.items = defaultStorage.load()

        setupMonitoring()
    }

    public init(storage: StorageService) {
        self.storage = storage
        self.monitor = ClipboardMonitor()
        self.items = storage.load()

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
                self?.handleNewCopiedItem(newItem, imageData: imageData)
            }
        }

        if isMonitoring {
            monitor.start()
            ScreenshotWatcher.shared.start()
        }
    }

    public var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            // Filter by content type if selected
            if let selectedType = selectedTypeFilter, item.contentType != selectedType {
                return false
            }

            // Filter by search query
            if !query.isEmpty {
                let matchesContent = item.textContent?.localizedCaseInsensitiveContains(query) ?? false
                let matchesPreview = item.previewTitle.localizedCaseInsensitiveContains(query)
                let matchesSource = item.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false
                let matchesFiles = item.filePaths?.contains { $0.localizedCaseInsensitiveContains(query) } ?? false

                if !matchesContent && !matchesPreview && !matchesSource && !matchesFiles {
                    return false
                }
            }

            return true
        }.sorted { (lhs, rhs) -> Bool in
            // Pinned items stay at top, then newest first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
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
        // Save image if present
        if let data = imageData, newItem.contentType == .image {
            _ = storage.saveImageData(data, id: newItem.id)
        }

        // Deduplicate using contentHash
        if let existingIndex = items.firstIndex(where: { $0.contentHash == newItem.contentHash }) {
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
                sourceAppName: newItem.sourceAppName ?? existingItem.sourceAppName,
                sourceAppBundleID: newItem.sourceAppBundleID ?? existingItem.sourceAppBundleID,
                contentHash: newItem.contentHash
            )
            items.insert(updated, at: 0)
        } else {
            items.insert(newItem, at: 0)
        }

        enforceHistoryLimit()
        storage.save(items: items)
    }

    public func copyToClipboard(_ item: ClipboardItem) {
        monitor.markNextChangeAsIgnored()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.contentType {
        case .image:
            if let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
                pasteboard.writeObjects([image])
            }

        case .file:
            if let filePaths = item.filePaths {
                let fileURLs = filePaths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(fileURLs)
            }

        case .text, .code, .url, .rtf:
            if let rtf = item.rtfData {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        }

        // Move the item to top as recently used
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
                sourceAppName: existing.sourceAppName,
                sourceAppBundleID: existing.sourceAppBundleID,
                contentHash: existing.contentHash
            )
            items.insert(refreshed, at: 0)
            storage.save(items: items)
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

    private func enforceHistoryLimit() {
        guard items.count > maxHistoryLimit else { return }

        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        let allowedUnpinned = max(0, maxHistoryLimit - pinned.count)
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
}
