//
//  ClipboardItem.swift
//  clipplic
//

import Foundation

public enum ItemContentType: String, Codable, Sendable {
    case text
    case url
    case code
    case rtf
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let contentType: ItemContentType
    public let textContent: String
    public let rtfData: Data?
    public let createdAt: Date
    public var isPinned: Bool
    public let sourceAppName: String?
    public let sourceAppBundleID: String?

    public init(
        id: UUID = UUID(),
        contentType: ItemContentType = .text,
        textContent: String,
        rtfData: Data? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.rtfData = rtfData
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
    }

    public var previewTitle: String {
        let trimmed = textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Empty item"
        }
        // Take first line or up to 100 characters
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        return String(firstLine.prefix(120))
    }

    public var secondaryPreview: String? {
        let lines = textContent.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > 1 {
            return lines[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    public var characterCount: Int {
        textContent.count
    }

    public var lineCount: Int {
        textContent.components(separatedBy: .newlines).count
    }

    public var systemImageName: String {
        switch contentType {
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
