//
//  ContentView.swift
//  clipplic
//

import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var hoveredItemId: UUID? = nil
    @State private var copiedFeedbackId: UUID? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header & Search
            headerSection
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // MARK: - Filter Pills
            filterSection
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.25)

            // MARK: - Content List
            if manager.filteredItems.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemsListView
            }

            Divider()
                .opacity(0.25)

            // MARK: - Footer
            footerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 410, height: 530)
        .background(PopoverGlassBackground().ignoresSafeArea())
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearchFocused ? .accentColor : .secondary)
                .font(.system(size: 13, weight: .semibold))

            TextField("Search text, links, images, files...", text: Bindable(manager).searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSearchFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.18),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Filters
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "All", count: manager.items.count, isSelected: manager.selectedTypeFilter == nil) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = nil
                    }
                }
                FilterChip(title: "Images", systemImage: "photo", count: manager.imagesCount, isSelected: manager.selectedTypeFilter == .image) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = (manager.selectedTypeFilter == .image) ? nil : .image
                    }
                }
                FilterChip(title: "Files", systemImage: "folder", count: manager.filesCount, isSelected: manager.selectedTypeFilter == .file) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = (manager.selectedTypeFilter == .file) ? nil : .file
                    }
                }
                FilterChip(title: "Text", systemImage: "doc.text", isSelected: manager.selectedTypeFilter == .text) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = (manager.selectedTypeFilter == .text) ? nil : .text
                    }
                }
                FilterChip(title: "Links", systemImage: "link", isSelected: manager.selectedTypeFilter == .url) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = (manager.selectedTypeFilter == .url) ? nil : .url
                    }
                }
                FilterChip(title: "Code", systemImage: "chevron.left.forwardslash.chevron.right", isSelected: manager.selectedTypeFilter == .code) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.selectedTypeFilter = (manager.selectedTypeFilter == .code) ? nil : .code
                    }
                }
            }
        }
    }

    // MARK: - Items List
    private var itemsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(manager.filteredItems) { item in
                        ClipboardItemRow(
                            item: item,
                            storage: manager.storage,
                            isHovered: hoveredItemId == item.id,
                            isRecentlyCopied: copiedFeedbackId == item.id,
                            onCopy: {
                                performCopy(item)
                            },
                            onTogglePin: {
                                manager.togglePin(item)
                            },
                            onDelete: {
                                manager.deleteItem(item)
                            }
                        )
                        .id(item.id)
                        .onHover { isHovering in
                            if isHovering {
                                hoveredItemId = item.id
                            } else if hoveredItemId == item.id {
                                hoveredItemId = nil
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: manager.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))

            if manager.searchText.isEmpty {
                Text("Clipboard is empty")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Copy text, links, screenshots, or files")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                Text("No matching items")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Try searching with different keywords")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .padding()
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack(spacing: 8) {
            Button {
                manager.toggleMonitoring()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(manager.isMonitoring ? Color.green : Color.orange)
                        .frame(width: 6.5, height: 6.5)
                        .shadow(color: manager.isMonitoring ? Color.green.opacity(0.4) : Color.clear, radius: 2)
                    Text(manager.isMonitoring ? "Monitoring" : "Paused")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(manager.isMonitoring ? "Click to pause clipboard monitoring" : "Click to resume clipboard monitoring")

            Spacer()

            Text("\(manager.items.count) items")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))

            Menu {
                Button("Clear Unpinned Items") {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.clearHistory(includingPinned: false)
                    }
                }
                Button("Clear All History", role: .destructive) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        manager.clearHistory(includingPinned: true)
                    }
                }
                Divider()
                Button("Settings...") {
                    SettingsWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
                Divider()
                Button("Quit Clipplic") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13.5))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func performCopy(_ item: ClipboardItem) {
        manager.copyToClipboard(item)
        copiedFeedbackId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedFeedbackId == item.id {
                copiedFeedbackId = nil
            }
        }
    }
}

// MARK: - Row View with App Icons & High-Res Thumbnails
struct ClipboardItemRow: View {
    let item: ClipboardItem
    let storage: StorageService
    let isHovered: Bool
    let isRecentlyCopied: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .center, spacing: 10) {
                // Leading High-Visibility Thumbnail
                leadingVisualBadge

                // Text Content & Metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.previewTitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let secondary = item.secondaryPreview {
                        Text(secondary)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Metadata footer with App Icon
                    HStack(spacing: 5) {
                        AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 12)

                        if let appName = item.sourceAppName {
                            Text(appName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.85))
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.4))
                        }

                        Text(formattedTime(item.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))

                        if item.contentType == .image, let size = item.imageByteSize {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        } else if item.characterCount > 0 {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("\(item.characterCount) chars")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }

                Spacer(minLength: 4)

                // Action Controls
                HStack(spacing: 4) {
                    if isRecentlyCopied {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                            Text("Copied")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Color.green.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    } else if item.isPinned || isHovered {
                        Button(action: onTogglePin) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 11))
                                .foregroundColor(item.isPinned ? .orange : .secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin item" : "Pin item to top")
                    }

                    if isHovered && !isRecentlyCopied {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        .help("Delete item")
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy to Clipboard") {
                onCopy()
            }
            if item.contentType == .image, let fileName = item.imageFileName {
                Button("Open in Preview") {
                    let url = storage.imageURL(for: fileName)
                    NSWorkspace.shared.open(url)
                }
            }
            if item.contentType == .file, let files = item.filePaths {
                Button("Reveal in Finder") {
                    let urls = files.map { URL(fileURLWithPath: $0) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
            }
            Divider()
            Button(item.isPinned ? "Unpin" : "Pin to Top") {
                onTogglePin()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }

    @ViewBuilder
    private var leadingVisualBadge: some View {
        if item.contentType == .image, let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
        } else if item.contentType == .file, let files = item.filePaths, let first = files.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                .resizable()
                .frame(width: 26, height: 26)
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 26, height: 26)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    private var iconColor: Color {
        switch item.contentType {
        case .image:
            return .pink
        case .file:
            return .teal
        case .url:
            return .blue
        case .code:
            return .purple
        case .rtf:
            return .orange
        case .text:
            return .secondary
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4.5) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9.5))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))

                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}
