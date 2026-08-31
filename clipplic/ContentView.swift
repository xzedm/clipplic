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

            // MARK: - Content List
            if manager.filteredItems.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                itemsListView
            }

            Divider()

            // MARK: - Footer
            footerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 400, height: 530)
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13, weight: .medium))

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
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Filters
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(title: "All", isSelected: manager.selectedTypeFilter == nil) {
                    manager.selectedTypeFilter = nil
                }
                FilterChip(title: "Images", systemImage: "photo", isSelected: manager.selectedTypeFilter == .image) {
                    manager.selectedTypeFilter = (manager.selectedTypeFilter == .image) ? nil : .image
                }
                FilterChip(title: "Files", systemImage: "folder", isSelected: manager.selectedTypeFilter == .file) {
                    manager.selectedTypeFilter = (manager.selectedTypeFilter == .file) ? nil : .file
                }
                FilterChip(title: "Text", systemImage: "doc.text", isSelected: manager.selectedTypeFilter == .text) {
                    manager.selectedTypeFilter = (manager.selectedTypeFilter == .text) ? nil : .text
                }
                FilterChip(title: "Links", systemImage: "link", isSelected: manager.selectedTypeFilter == .url) {
                    manager.selectedTypeFilter = (manager.selectedTypeFilter == .url) ? nil : .url
                }
                FilterChip(title: "Code", systemImage: "chevron.left.forwardslash.chevron.right", isSelected: manager.selectedTypeFilter == .code) {
                    manager.selectedTypeFilter = (manager.selectedTypeFilter == .code) ? nil : .code
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
                .foregroundColor(.secondary.opacity(0.6))

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
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.isMonitoring ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(manager.isMonitoring ? "Monitoring" : "Paused")
                        .font(.system(size: 11))
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
                    manager.clearHistory(includingPinned: false)
                }
                Button("Clear All History", role: .destructive) {
                    manager.clearHistory(includingPinned: true)
                }
                Divider()
                Button("Quit Clipplic") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
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

// MARK: - Row View
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
                // High-visibility thumbnail or visual badge
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
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Metadata footer
                    HStack(spacing: 6) {
                        Text(formattedTime(item.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))

                        if let appName = item.sourceAppName {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(appName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.8))
                        }

                        if item.contentType == .image, let size = item.imageByteSize {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        } else if item.characterCount > 0 {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.5))
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
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                            Text("Copied")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)
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
                RoundedRectangle(cornerRadius: 6)
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
                .frame(width: 36, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
        } else if item.contentType == .file, let files = item.filePaths, let first = files.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                .resizable()
                .frame(width: 26, height: 26)
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 26, height: 26)
                .background(iconColor.opacity(0.12))
                .cornerRadius(5)
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 9.5))
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual Effect View for macOS frosted glass look
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
