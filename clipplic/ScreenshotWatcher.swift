//
//  ScreenshotWatcher.swift
//  clipplic
//

import AppKit
import CryptoKit
import Foundation

@MainActor
public final class ScreenshotWatcher {
    public static let shared = ScreenshotWatcher()

    private var directorySource: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var knownScreenshotPaths = Set<String>()
    private var isWatching: Bool = false

    public var onScreenshotCaptured: ((ClipboardItem, Data) -> Void)?

    private init() {
        populateInitialFiles()
    }

    public func start() {
        guard !isWatching else { return }
        populateInitialFiles()

        let folderURL = screenshotDirectoryURL()
        fileDescriptor = open(folderURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("[ScreenshotWatcher] Failed to open folder: \(folderURL.path)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.checkForNewScreenshots()
        }

        let fd = fileDescriptor
        source.setCancelHandler {
            if fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        self.directorySource = source
        self.isWatching = true
    }

    public func stop() {
        guard isWatching else { return }
        directorySource?.cancel()
        directorySource = nil
        fileDescriptor = -1
        isWatching = false
    }

    private func screenshotDirectoryURL() -> URL {
        if let customLocation = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"),
           !customLocation.isEmpty {
            let expanded = NSString(string: customLocation).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Default: ~/Desktop
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    }

    private func populateInitialFiles() {
        let folderURL = screenshotDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) else { return }
        for file in files where isScreenshotFilename(file) {
            knownScreenshotPaths.insert(folderURL.appendingPathComponent(file).path)
        }
        // Cap the set to prevent unbounded growth
        if knownScreenshotPaths.count > 500 {
            knownScreenshotPaths.removeAll()
        }
    }

    private func checkForNewScreenshots() {
        let folderURL = screenshotDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) else { return }

        for file in files where isScreenshotFilename(file) {
            let filePath = folderURL.appendingPathComponent(file).path
            if !knownScreenshotPaths.contains(filePath) {
                knownScreenshotPaths.insert(filePath)

                // Wait for macOS to finish writing the file, then verify stability
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.processNewScreenshotIfStable(at: filePath, attempt: 1)
                }
            }
        }
    }

    private func processNewScreenshotIfStable(at path: String, attempt: Int) {
        let fileURL = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0,
              let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            // Retry up to 3 times with increasing delay
            if attempt < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.3) { [weak self] in
                    self?.processNewScreenshotIfStable(at: path, attempt: attempt + 1)
                }
            }
            return
        }
        processScreenshotData(data, image: image, path: path)
    }

    private func processScreenshotData(_ data: Data, image: NSImage, path: String) {

        let itemId = UUID()
        let fileName = "\(itemId.uuidString).png"
        let hashString = "img:" + SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

        let item = ClipboardItem(
            id: itemId,
            contentType: .image,
            textContent: nil,
            imageFileName: fileName,
            imageWidth: Double(image.size.width),
            imageHeight: Double(image.size.height),
            imageByteSize: data.count,
            filePaths: [path],
            createdAt: Date(),
            isPinned: false,
            sourceAppName: "Screenshot",
            sourceAppBundleID: "com.apple.screencapture",
            contentHash: hashString
        )

        onScreenshotCaptured?(item, data)
    }

    private func isScreenshotFilename(_ name: String) -> Bool {
        let lower = name.lowercased()
        let isImage = lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".heic")
        guard isImage else { return false }

        // Common macOS screenshot naming conventions across languages
        return lower.hasPrefix("screenshot") ||
               lower.hasPrefix("screen shot") ||
               lower.hasPrefix("снимок экрана") ||
               lower.hasPrefix("capture d’écran") ||
               lower.hasPrefix("bildschirmfoto") ||
               lower.hasPrefix("skjermbilde") ||
               lower.hasPrefix("captura de pantalla")
    }
}
