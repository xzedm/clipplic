//
//  StorageService.swift
//  clipplic
//

import AppKit
import Foundation

@MainActor
public final class StorageService {
    private let directoryURL: URL
    private let imagesDirectoryURL: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let imageMemoryCache = NSCache<NSString, NSImage>()
    private var lastOrphanCleanup: Date = .distantPast
    public init(folderName: String = "clipplic", fileName: String = "history.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directoryURL = appSupport.appendingPathComponent(folderName, isDirectory: true)
        self.imagesDirectoryURL = directoryURL.appendingPathComponent("images", isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent(fileName)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        imageMemoryCache.countLimit = 80
        imageMemoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB RAM cap

        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: imagesDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
        }
    }

    public func save(items: [ClipboardItem]) {
        ensureDirectoriesExist()
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
            // Restrict file permissions to owner-only read/write
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            print("[StorageService] Failed to save history: \(error.localizedDescription)")
        }

        // Clean up orphaned images at most once per 5 minutes
        if Date().timeIntervalSince(lastOrphanCleanup) > 300 {
            lastOrphanCleanup = Date()
            let referencedImages = Set(items.compactMap { $0.imageFileName })
            cleanupOrphanedImages(activeImageFileNames: referencedImages)
        }
    }

    public func load() -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let items = try decoder.decode([ClipboardItem].self, from: data)
            return items
        } catch {
            print("[StorageService] Failed to load history: \(error.localizedDescription)")
            return []
        }
    }

    public func clear() {
        imageMemoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: imagesDirectoryURL)
        ensureDirectoriesExist()
    }

    // MARK: - Image Cache Management
    public func saveImageData(_ data: Data, id: UUID) -> String? {
        ensureDirectoriesExist()
        let fileName = "\(id.uuidString).png"
        let destinationURL = imagesDirectoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: destinationURL, options: .atomic)
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
        let url = imageURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanupOrphanedImages(activeImageFileNames: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectoryURL.path) else {
            return
        }
        for file in files {
            if !activeImageFileNames.contains(file) {
                let fileURL = imagesDirectoryURL.appendingPathComponent(file)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
