//
//  StorageService.swift
//  clipplic
//

import Foundation

@MainActor
public final class StorageService {
    private let directoryURL: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(folderName: String = "clipplic", fileName: String = "history.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directoryURL = appSupport.appendingPathComponent(folderName, isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent(fileName)

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    public func save(items: [ClipboardItem]) {
        ensureDirectoryExists()
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[StorageService] Failed to save history: \(error.localizedDescription)")
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
        try? FileManager.default.removeItem(at: fileURL)
    }
}


