//
//  ScreenshotWatcher.swift
//  clipplic
//

import AppKit
import CoreServices
import CryptoKit
import Foundation
import ImageIO

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
        // Mark every existing file as seen. Do NOT clear this set: if it were emptied, the next
        // folder event would re-import every old screenshot at once (memory/CPU spike, history flood).
        // Paths are small strings, so even thousands of entries cost very little.
        for file in files {
            knownScreenshotPaths.insert(folderURL.appendingPathComponent(file).path)
        }
    }

    private func checkForNewScreenshots() {
        let folderURL = screenshotDirectoryURL()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) else { return }

        for file in files {
            let filePath = folderURL.appendingPathComponent(file).path
            guard !knownScreenshotPaths.contains(filePath) else { continue }
            // Record before classifying so non-screenshot files aren't re-queried in Spotlight on every folder event
            knownScreenshotPaths.insert(filePath)
            guard isScreenshotFilename(file) || isScreenCapturePath(filePath) else { continue }

            // Ultra-low latency: start verifying file readiness in 50ms
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.processNewScreenshotIfStable(at: filePath, attempt: 1)
            }
        }
    }

    private func processNewScreenshotIfStable(at path: String, attempt: Int) {
        let fileURL = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > 0,
              let data = try? Data(contentsOf: fileURL),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(source) == .statusComplete,
              let image = NSImage(data: data) else {
            // Progressive retry up to 5 times (100ms, 200ms, 300ms, 400ms, 500ms)
            if attempt < 6 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.1) { [weak self] in
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

        // Check custom screenshot name prefix configured by user in screencapture defaults
        if let customName = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "name")?.lowercased(),
           !customName.isEmpty, lower.hasPrefix(customName) {
            return true
        }

        // Common macOS screenshot naming conventions across languages
        let prefixes = [
            "screenshot", "screen shot",
            "снимок экрана",
            "capture d’écran", "capture d'écran",
            "bildschirmfoto",
            "skjermbilde", "skärmavbild",
            "captura de pantalla",
            "schermafbeelding", "schermopname",
            "istantanea",
            "zrzut ekranu",
            "snimka zaslona",
            "ekran görüntüsü", "ekran resmi",
            "skjermdump",
            "kuvakaappaus",
            "截屏", "屏幕快照",
            "スクリーンショット",
            "스크린샷"
        ]

        return prefixes.contains { lower.hasPrefix($0) }
    }

    private func isScreenCapturePath(_ path: String) -> Bool {
        let lower = path.lowercased()
        let isImage = lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".heic")
        guard isImage else { return false }

        // Spotlight metadata check for native macOS screencapture tags
        let fileURL = URL(fileURLWithPath: path)
        if let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, fileURL as CFURL) {
            if let isCapture = MDItemCopyAttribute(mdItem, "kMDItemIsScreenCapture" as CFString) as? Bool, isCapture {
                return true
            }
            if let isCaptureNum = MDItemCopyAttribute(mdItem, "kMDItemIsScreenCapture" as CFString) as? NSNumber, isCaptureNum.boolValue {
                return true
            }
        }
        return false
    }
}
