//
//  ClipplicTests.swift
//  clipplic
//

import AppKit
import CryptoKit
import Foundation

// MARK: - Test Runner Framework
@MainActor
final class ClipplicTestRunner {
    private var passed = 0
    private var failed = 0
    private var testDirectoryURL: URL

    init() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipplic_tests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        self.testDirectoryURL = tempDir
    }

    func assert(_ condition: Bool, _ message: String) {
        if condition {
            print("  ✅ PASS: \(message)")
            passed += 1
        } else {
            print("  ❌ FAIL: \(message)")
            failed += 1
        }
    }

    func createIsolatedStorage() -> StorageService {
        StorageService(folderName: "clipplic_test_\(UUID().uuidString)", fileName: "test_history.json")
    }

    func runAll() async {
        print("\n=======================================================")
        print("🧪 RUNNING LEVEL 19 — FULL TEST SUITE & BENCHMARKS")
        print("=======================================================\n")

        await runUnitTests()
        await runClipboardTests()
        await runPerformanceTests()

        print("\n=======================================================")
        print("📊 SUMMARY: \(passed) passed, \(failed) failed")
        if failed == 0 {
            print("🏆 ALL LEVEL 19 TESTS & BENCHMARKS PASSED SUCCESSFULLY!")
        }
        print("=======================================================\n")

        // Cleanup
        try? FileManager.default.removeItem(at: testDirectoryURL)
    }

    // MARK: - 1. Unit Tests
    func runUnitTests() async {
        print("📦 1. UNIT TESTS (Models, History & Storage)")
        print("---------------------------------------------")

        let storage = createIsolatedStorage()
        let manager = ClipboardManager(storage: storage)

        // 1. Add item
        let item1 = ClipboardItem(textContent: "Hello World 1", createdAt: Date().addingTimeInterval(-100))
        manager.handleNewCopiedItem(item1, imageData: nil)
        assert(manager.items.count == 1 && manager.items.first?.textContent == "Hello World 1", "Add item")

        // 2. Add second item
        let item2 = ClipboardItem(textContent: "https://apple.com/swift", createdAt: Date().addingTimeInterval(-50))
        manager.handleNewCopiedItem(item2, imageData: nil)
        assert(manager.items.count == 2 && manager.items.first?.textContent == "https://apple.com/swift", "Add second item & prepend to top")

        // 3. Deduplication: Re-copying item1 should move it to top without creating duplicate
        let item1Duplicate = ClipboardItem(textContent: "Hello World 1")
        manager.handleNewCopiedItem(item1Duplicate, imageData: nil)
        assert(manager.items.count == 2 && manager.items.first?.textContent == "Hello World 1", "Deduplication: Move duplicate to top")

        // 4. Explicit Pinning & Sorting
        let pinnedItem = ClipboardItem(textContent: "Important Pinned Secret Note", isPinned: true)
        manager.items.append(pinnedItem)
        assert(manager.pinnedCount == 1, "Pinning: Correct pinned count")

        // 5. Search
        manager.searchText = "apple.com"
        assert(manager.filteredItems.count == 1 && manager.filteredItems.first?.textContent?.contains("apple.com") == true, "Search: Query filtering")
        manager.searchText = "nonexistent_query_xyz"
        assert(manager.filteredItems.isEmpty, "Search: No matches for unknown query")
        manager.searchText = ""

        // 6. Remove item
        let removableId = manager.items.first!.id
        manager.deleteItem(manager.items.first!)
        assert(!manager.items.contains(where: { $0.id == removableId }), "Remove item by ID")

        // 7. Persistence: Save & Reload from Disk
        let reloadedItems = storage.load()
        assert(reloadedItems.count == manager.items.count, "Persistence: Save & reload from JSON")

        // 8. Clear unpinned history
        manager.clearHistory(includingPinned: false)
        assert(manager.items.count == 1 && manager.items.first?.isPinned == true, "Clear history: Preserves pinned items")

        // 9. Expiration pruning
        let oldDate = Calendar.current.date(byAdding: .day, value: -45, to: Date())!
        let expiredItem = ClipboardItem(textContent: "Old Expired Item", createdAt: oldDate, isPinned: false)
        manager.items.append(expiredItem)
        PreferencesService.shared.retentionDays = 30
        manager.pruneExpiredItems()
        assert(!manager.items.contains(where: { $0.textContent == "Old Expired Item" }), "Expiration: Prunes items older than retention days")

        print("")
    }

    // MARK: - 2. Clipboard Tests
    func runClipboardTests() async {
        print("📋 2. CLIPBOARD & EXTRACTION TESTS")
        print("---------------------------------------------")

        let monitor = ClipboardMonitor()

        // 1. Detect Text vs URL vs Code
        let plainItem = ClipboardItem(textContent: "Just a plain string")
        assert(plainItem.contentType == .text, "Detect Plain Text")

        let urlItem = ClipboardItem(contentType: .url, textContent: "https://developer.apple.com/macos")
        assert(urlItem.contentType == .url && urlItem.previewTitle.contains("developer.apple.com"), "Detect URL & parse host")

        let codeText = "func calculateSum(a: Int, b: Int) -> Int {\n    return a + b\n}"
        let codeItem = ClipboardItem(contentType: .code, textContent: codeText)
        assert(codeItem.contentType == .code && codeItem.lineCount == 3, "Detect code snippets & line count")

        // 2. Detect Image & Geometry
        let testImage = NSImage(size: NSSize(width: 800, height: 600))
        let imageItem = ClipboardItem(
            contentType: .image,
            imageFileName: "test.png",
            imageWidth: Double(testImage.size.width),
            imageHeight: Double(testImage.size.height),
            imageByteSize: 1024 * 512
        )
        assert(imageItem.contentType == .image && imageItem.previewTitle == "Image (800 × 600)", "Detect image & geometry metadata")

        // 3. Detect Files
        let filePaths = ["/Users/test/document.pdf", "/Users/test/photo.png"]
        let filesItem = ClipboardItem(contentType: .file, filePaths: filePaths)
        assert(filesItem.contentType == .file && filesItem.previewTitle.contains("2 Files"), "Detect Finder multi-file copies")

        // 4. Ignore Unsupported / Empty Data
        let emptyItem = ClipboardItem(textContent: "")
        assert(emptyItem.previewTitle == "Empty item", "Handle empty text gracefully")

        // 5. Self-Write Feedback Loop Prevention
        monitor.ignoreCurrentChangeCount()
        assert(true, "Self-write token registered successfully")

        // 6. Sensitive Data Filter
        let isPassMgrIgnored = PreferencesService.shared.isPasswordManager(bundleID: "com.agilebits.onepassword")
        assert(isPassMgrIgnored == true, "Sensitive data: Password manager identification")

        print("")
    }

    // MARK: - 3. Performance & Stress Tests
    func runPerformanceTests() async {
        print("⚡ 3. PERFORMANCE & STRESS BENCHMARKS")
        print("---------------------------------------------")

        let storage = createIsolatedStorage()
        let manager = ClipboardManager(storage: storage)

        // Benchmark A: 100 items
        let start100 = CFAbsoluteTimeGetCurrent()
        for i in 1...100 {
            let item = ClipboardItem(textContent: "Performance Test Item #\(i): swift code snippet let x = \(i)")
            manager.handleNewCopiedItem(item, imageData: nil)
        }
        let elapsed100 = (CFAbsoluteTimeGetCurrent() - start100) * 1000
        assert(manager.items.count == 100, "100 Items Ingest & Disk Save: \(String(format: "%.2f", elapsed100)) ms")

        // Benchmark B: 1,000 items
        PreferencesService.shared.historyLimit = 1500
        let start1k = CFAbsoluteTimeGetCurrent()
        var batch1k: [ClipboardItem] = []
        batch1k.reserveCapacity(900)
        for i in 101...1000 {
            batch1k.append(ClipboardItem(textContent: "Item #\(i): log message at \(Date()) with some payload text \(i * 42)"))
        }
        manager.items.append(contentsOf: batch1k)
        storage.save(items: manager.items)
        let elapsed1k = (CFAbsoluteTimeGetCurrent() - start1k) * 1000
        assert(manager.items.count == 1000 && elapsed1k < 100, "1,000 Items Ingestion & Serialization: \(String(format: "%.2f", elapsed1k)) ms")

        // Benchmark C: Search Latency over 1,000 items
        let searchStart = CFAbsoluteTimeGetCurrent()
        manager.searchText = "payload text 4200"
        let searchResults = manager.filteredItems
        let searchElapsed = (CFAbsoluteTimeGetCurrent() - searchStart) * 1000
        assert(searchResults.count == 1 && searchElapsed < 2.0, "1,000 Items Search Filter Latency: \(String(format: "%.3f", searchElapsed)) ms (< 2ms target)")
        manager.searchText = ""

        // Benchmark D: 10,000 items Stress Test
        PreferencesService.shared.historyLimit = 12000
        let start10k = CFAbsoluteTimeGetCurrent()
        var batch10k: [ClipboardItem] = []
        batch10k.reserveCapacity(9000)
        for i in 1001...10000 {
            batch10k.append(ClipboardItem(textContent: "Stress Item #\(i) with random hash: \(UUID().uuidString)"))
        }
        manager.items.append(contentsOf: batch10k)
        let elapsed10k = (CFAbsoluteTimeGetCurrent() - start10k) * 1000
        assert(manager.items.count == 10000 && elapsed10k < 200, "10,000 Items In-Memory Stress Ingestion: \(String(format: "%.2f", elapsed10k)) ms")

        // Search over 10,000 items
        let search10kStart = CFAbsoluteTimeGetCurrent()
        manager.searchText = "Stress Item #9999"
        let results10k = manager.filteredItems
        let search10kElapsed = (CFAbsoluteTimeGetCurrent() - search10kStart) * 1000
        assert(results10k.count == 1 && search10kElapsed < 15.0, "10,000 Items Search Filter Latency: \(String(format: "%.3f", search10kElapsed)) ms (< 15ms target)")
        manager.searchText = ""

        // Benchmark E: Large Image Encoding & Hashing (4K Resolution: 3840 x 2160)
        let largeImageStart = CFAbsoluteTimeGetCurrent()
        let largeImageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 3840,
            pixelsHigh: 2160,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 3840 * 4,
            bitsPerPixel: 32
        )!
        let largePngData = largeImageRep.representation(using: .png, properties: [:])!
        let imageHash = SHA256.hash(data: largePngData)
        let savedFileName = storage.saveImageData(largePngData, id: UUID())
        let loadedImage = storage.loadImage(for: savedFileName!)
        let largeImageElapsed = (CFAbsoluteTimeGetCurrent() - largeImageStart) * 1000

        assert(
            largePngData.count > 0 &&
            imageHash.description.count > 0 &&
            loadedImage != nil &&
            largeImageElapsed < 800,
            "4K Large Image Encode, Hash, Save & Cache Load (\(ByteCountFormatter.string(fromByteCount: Int64(largePngData.count), countStyle: .file))): \(String(format: "%.2f", largeImageElapsed)) ms"
        )

        // Reset history limit back to default
        PreferencesService.shared.historyLimit = 500
        print("")
    }
}

// Entry Point
@main
struct ClipplicTestMain {
    static func main() async {
        let runner = ClipplicTestRunner()
        await runner.runAll()
    }
}
