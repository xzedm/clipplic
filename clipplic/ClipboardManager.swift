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
    private let storage: StorageService

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
        monitor.onItemCopied = { [weak self] newItem in
            Task { @MainActor [weak self] in
                self?.handleNewCopiedItem(newItem)
            }
        }
        if isMonitoring {
            monitor.start()
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
                let matchesContent = item.textContent.localizedCaseInsensitiveContains(query)
                let matchesSource = item.sourceAppName?.localizedCaseInsensitiveContains(query) ?? false
                if !matchesContent && !matchesSource {
                    return false
                }
            }

            return true
        }.sorted { (lhs, rhs) -> Bool in
            // Pinned items stay at the top, then newest first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    public var pinnedCount: Int {
        items.filter { $0.isPinned }.count
    }

    public var todayCount: Int {
        let calendar = Calendar.current
        return items.filter { calendar.isDateInToday($0.createdAt) }.count
    }

    public func handleNewCopiedItem(_ newItem: ClipboardItem) {
        // Check for existing identical content to deduplicate
        if let existingIndex = items.firstIndex(where: { $0.textContent == newItem.textContent }) {
            let existingItem = items.remove(at: existingIndex)
            // Preserve pin status, update timestamp and source if available
            let updated = ClipboardItem(
                id: existingItem.id,
                contentType: newItem.contentType,
                textContent: newItem.textContent,
                rtfData: newItem.rtfData ?? existingItem.rtfData,
                createdAt: Date(),
                isPinned: existingItem.isPinned,
                sourceAppName: newItem.sourceAppName ?? existingItem.sourceAppName,
                sourceAppBundleID: newItem.sourceAppBundleID ?? existingItem.sourceAppBundleID
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

        if let rtf = item.rtfData {
            pasteboard.setData(rtf, forType: .rtf)
        }
        pasteboard.setString(item.textContent, forType: .string)

        // Move the item to top as recently used
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let updated = items.remove(at: index)
            let refreshed = ClipboardItem(
                id: updated.id,
                contentType: updated.contentType,
                textContent: updated.textContent,
                rtfData: updated.rtfData,
                createdAt: Date(),
                isPinned: updated.isPinned,
                sourceAppName: updated.sourceAppName,
                sourceAppBundleID: updated.sourceAppBundleID
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
        items.removeAll { $0.id == item.id }
        storage.save(items: items)
    }

    public func clearHistory(includingPinned: Bool = false) {
        if includingPinned {
            items.removeAll()
        } else {
            items.removeAll { !$0.isPinned }
        }
        storage.save(items: items)
    }

    public func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            monitor.start()
        } else {
            monitor.stop()
        }
    }

    private func enforceHistoryLimit() {
        guard items.count > maxHistoryLimit else { return }

        // Keep all pinned items, trim oldest unpinned items
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        let allowedUnpinned = max(0, maxHistoryLimit - pinned.count)
        let trimmedUnpinned = Array(unpinned.prefix(allowedUnpinned))

        items = (pinned + trimmedUnpinned).sorted { $0.createdAt > $1.createdAt }
    }
}
