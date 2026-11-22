//
//  StorageService.swift
//  clipplic
//

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
public final class StorageService {
    private let directoryURL: URL
    private let imagesDirectoryURL: URL
    private let thumbnailsDirectoryURL: URL
    /// Longest side of list thumbnails in pixels (rows draw images at 36 pt, so this covers 2x and 3x).
    static let thumbnailMaxPixelSize = 144
    private let fileURL: URL
    private let decoder: JSONDecoder
    /// Serial queue for history writes: encoding hundreds of items blocked the UI on the main thread.
    private let writeQueue = DispatchQueue(label: "app.clipplic.storage.write", qos: .utility)
    /// Bumped on every save so queued writes that were superseded can be skipped.
    private let writeGeneration = WriteGeneration()
    private let imageMemoryCache = NSCache<NSString, NSImage>()
    private var lastOrphanCleanup: Date = .distantPast
    public init(folderName: String = "clipplic", fileName: String = "history.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directoryURL = appSupport.appendingPathComponent(folderName, isDirectory: true)
        self.imagesDirectoryURL = directoryURL.appendingPathComponent("images", isDirectory: true)
        self.thumbnailsDirectoryURL = directoryURL.appendingPathComponent("thumbnails", isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent(fileName)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        imageMemoryCache.countLimit = 80
        imageMemoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB RAM cap

        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        // Owner-only access: clipboard history and screenshots may contain secrets
        let ownerOnly: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        for url in [directoryURL, imagesDirectoryURL, thumbnailsDirectoryURL] {
            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: ownerOnly)
            } else {
                try? FileManager.default.setAttributes(ownerOnly, ofItemAtPath: url.path)
            }
        }
    }

    /// Saves history in the background. Writes stay in order, and a write that a newer save replaces is skipped.
    public func save(items: [ClipboardItem]) {
        ensureDirectoriesExist()
        let generation = writeGeneration.next()
        let fileURL = fileURL
        let imagesDirectoryURL = imagesDirectoryURL
        let thumbnailsDirectoryURL = thumbnailsDirectoryURL

        var referencedImages: Set<String>? = nil
        // Clean up orphaned images at most once per 5 minutes
        if Date().timeIntervalSince(lastOrphanCleanup) > 300 {
            lastOrphanCleanup = Date()
            referencedImages = Set(items.compactMap { $0.imageFileName })
        }

        let writeGeneration = writeGeneration
        writeQueue.async {
            if writeGeneration.isLatest(generation) {
                Self.write(items, to: fileURL)
            }
            if let referencedImages {
                Self.cleanupOrphanedImages(in: imagesDirectoryURL, keeping: referencedImages)
                Self.cleanupOrphanedImages(in: thumbnailsDirectoryURL, keeping: referencedImages)
            }
        }
    }

    /// Blocks until every queued write is on disk. Call it before quitting.
    public func flush() {
        writeQueue.sync {}
    }

    private nonisolated static func write(_ items: [ClipboardItem], to fileURL: URL) {
        let encoder = JSONEncoder()
        // Compact output: history can hold hundreds of items with RTF payloads
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
            // Restrict file permissions to owner-only read/write
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            print("[StorageService] Failed to save history: \(error.localizedDescription)")
        }
    }

    public func load() -> [ClipboardItem] {
        flush()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items
        } catch {
            print("[StorageService] Failed to load history: \(error.localizedDescription)")
            // Keep the unreadable file aside; otherwise the next save silently overwrites the whole history
            let backupURL = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: backupURL)
            return []
        }
    }

    public func clear() {
        imageMemoryCache.removeAllObjects()
        // Drop queued writes so an older history can't reappear after clearing.
        _ = writeGeneration.next()
        flush()
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: imagesDirectoryURL)
        try? FileManager.default.removeItem(at: thumbnailsDirectoryURL)
        ensureDirectoriesExist()
    }

    // MARK: - Image Cache Management
    public func saveImageData(_ data: Data, id: UUID) -> String? {
        ensureDirectoriesExist()
        let fileName = "\(id.uuidString).png"
        let destinationURL = imagesDirectoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: destinationURL, options: .atomic)
            makeThumbnail(from: destinationURL, fileName: fileName)
            return fileName
        } catch {
            print("[StorageService] Failed to save image data: \(error.localizedDescription)")
            return nil
        }
    }

    public func imageURL(for fileName: String) -> URL {
        imagesDirectoryURL.appendingPathComponent(fileName)
    }

    public func loadImage(for fileName: String) -> NSImage? {
        let key = fileName as NSString
        if let cached = imageMemoryCache.object(forKey: key) {
            return cached
        }

        let url = imageURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        imageMemoryCache.setObject(image, forKey: key)
        return image
    }

    public func deleteImage(for fileName: String) {
        imageMemoryCache.removeObject(forKey: fileName as NSString)
        imageMemoryCache.removeObject(forKey: Self.thumbnailCacheKey(fileName))
        try? FileManager.default.removeItem(at: imageURL(for: fileName))
        try? FileManager.default.removeItem(at: thumbnailURL(for: fileName))
    }

    // MARK: - Thumbnails

    public func thumbnailURL(for fileName: String) -> URL {
        thumbnailsDirectoryURL.appendingPathComponent(fileName)
    }

    /// Small image for list rows. Images saved before thumbnails existed get one made the first time they're shown.
    public func loadThumbnail(for fileName: String) -> NSImage? {
        let key = Self.thumbnailCacheKey(fileName)
        if let cached = imageMemoryCache.object(forKey: key) {
            return cached
        }

        let url = thumbnailURL(for: fileName)
        var image = NSImage(contentsOf: url)
        if image == nil {
            image = makeThumbnail(from: imageURL(for: fileName), fileName: fileName)
        }
        guard let image else { return nil }

        let cost = Self.thumbnailMaxPixelSize * Self.thumbnailMaxPixelSize * 4
        imageMemoryCache.setObject(image, forKey: key, cost: cost)
        return image
    }

    /// Downsamples without decoding the full image, then saves the result as PNG.
    @discardableResult
    private func makeThumbnail(from sourceURL: URL, fileName: String) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let destinationURL = thumbnailURL(for: fileName)
        if let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(destination, cgImage, nil)
            CGImageDestinationFinalize(destination)
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private static func thumbnailCacheKey(_ fileName: String) -> NSString {
        "thumb:\(fileName)" as NSString
    }

    private nonisolated static func cleanupOrphanedImages(in directory: URL, keeping activeImageFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return
        }
        // The item list is a snapshot, so skip recent files: an image saved since then may not be in it yet.
        let cutoff = Date().addingTimeInterval(-600)
        for file in files where !activeImageFileNames.contains(file) {
            let fileURL = directory.appendingPathComponent(file)
            let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

/// Thread-safe counter that marks which queued history write is the newest.
private final class WriteGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        value += 1
        return value
    }

    func isLatest(_ generation: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return generation == value
    }
}
