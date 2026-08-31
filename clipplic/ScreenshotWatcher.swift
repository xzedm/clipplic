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

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
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
    }

    private func checkForNewScreenshots() {
        let folderURL = screenshotDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) else { return }

        for file in files where isScreenshotFilename(file) {
            let filePath = folderURL.appendingPathComponent(file).path
            if !knownScreenshotPaths.contains(filePath) {
                knownScreenshotPaths.insert(filePath)

                // Wait 150ms for macOS to finish writing the file to disk
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.processNewScreenshot(at: filePath)
                }
            }
        }
    }

    private func processNewScreenshot(at path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let image = NSImage(data: data) else {
            return
        }

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
