//
//  ClipboardItem.swift
//  clipplic
//

import Foundation

public enum ItemContentType: String, Codable, Sendable, CaseIterable {
    case text
    case url
    case code
    case rtf
    case image
    case file
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let contentType: ItemContentType
    public let textContent: String?
    public let rtfData: Data?
    public let imageFileName: String?
    public let imageWidth: Double?
    public let imageHeight: Double?
    public let imageByteSize: Int?
    public let filePaths: [String]?
    public let createdAt: Date
    public var isPinned: Bool
    public let sourceAppName: String?
    public let sourceAppBundleID: String?
    public let contentHash: String

    public init(
        id: UUID = UUID(),
        contentType: ItemContentType = .text,
        textContent: String? = nil,
        rtfData: Data? = nil,
        imageFileName: String? = nil,
        imageWidth: Double? = nil,
        imageHeight: Double? = nil,
        imageByteSize: Int? = nil,
        filePaths: [String]? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil,
        contentHash: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.rtfData = rtfData
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageByteSize = imageByteSize
        self.filePaths = filePaths
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID

        if let hash = contentHash {
            self.contentHash = hash
        } else {
            // Compute default hash
            if let text = textContent {
                self.contentHash = "text:\(text)"
            } else if let img = imageFileName {
                self.contentHash = "img:\(img)"
            } else if let files = filePaths {
                self.contentHash = "files:\(files.joined(separator: "|"))"
            } else {
                self.contentHash = id.uuidString
            }
        }
    }

    public var previewTitle: String {
        switch contentType {
        case .image:
            if let w = imageWidth, let h = imageHeight {
                return "Image (\(Int(w)) × \(Int(h)))"
            }
            if let size = imageByteSize {
                return "Image (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))"
            }
            return "Image"

        case .file:
            guard let files = filePaths, !files.isEmpty else {
                return "Empty file selection"
            }
            if files.count == 1 {
                return URL(fileURLWithPath: files[0]).lastPathComponent
            } else {
                let first = URL(fileURLWithPath: files[0]).lastPathComponent
                return "\(files.count) Files (\(first), +\(files.count - 1))"
            }

        case .url:
            if let text = textContent?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if let url = URL(string: text), let host = url.host {
                    return host + url.path
                }
                return text
            }
            return "Link"

        case .text, .code, .rtf:
            let trimmed = (textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Empty item"
            }
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            return String(firstLine.prefix(120))
        }
    }

    public var secondaryPreview: String? {
        switch contentType {
        case .image:
            var details: [String] = []
            if let size = imageByteSize {
                details.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
            if let w = imageWidth, let h = imageHeight {
                details.append("\(Int(w))×\(Int(h)) px")
            }
            return details.isEmpty ? "Screenshot / Image" : details.joined(separator: " • ")

        case .file:
            guard let files = filePaths, !files.isEmpty else { return nil }
            if files.count == 1 {
                let url = URL(fileURLWithPath: files[0])
                return url.deletingLastPathComponent().path
            } else {
                return files.map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: ", ")
            }

        case .text, .code, .rtf, .url:
            guard let text = textContent else { return nil }
            let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            if lines.count > 1 {
                return lines[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
    }

    public var characterCount: Int {
        textContent?.count ?? 0
    }

    public var lineCount: Int {
        textContent?.components(separatedBy: .newlines).count ?? 0
    }

    public var systemImageName: String {
        switch contentType {
        case .image:
            return "photo"
        case .file:
            if let files = filePaths, files.count == 1 {
                let isDirectory = (try? URL(fileURLWithPath: files[0]).resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                return isDirectory ? "folder" : "doc"
            }
            return "doc.on.doc"
        case .url:
            return "link"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .rtf:
            return "doc.richtext"
        case .text:
            return "doc.text"
        }
    }
}
