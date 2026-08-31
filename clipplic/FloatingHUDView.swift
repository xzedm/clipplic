//
//  FloatingHUDView.swift
//  clipplic
//

import SwiftUI

struct FloatingHUDView: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var selectedItemId: UUID? = nil
    @State private var isShowingQuickLook: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var localKeyMonitor: Any? = nil
    @State private var hoveredItemId: UUID? = nil
    @State private var showingClearConfirmation: Bool = false

    private var items: [ClipboardItem] {
        manager.filteredItems
    }

    private var selectedItem: ClipboardItem? {
        if let id = selectedItemId, let item = items.first(where: { $0.id == id }) {
            return item
        }
        return items.first
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Search Header & Quick Controls
                searchHeaderView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                // MARK: - Filter Pills
                filterSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Divider()
                    .opacity(0.25)

                // MARK: - Main Dual-Pane Content
                if items.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // Left list (45% width)
                        itemListPane
                            .frame(width: 335)

                        Divider()
                            .opacity(0.25)

                        // Right detail preview pane (55% width)
                        detailPreviewPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                Divider()
                    .opacity(0.25)

                // MARK: - Interactive Action Buttons Footer Bar
                interactiveFooterBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .frame(width: 750, height: 520)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 16)

            // MARK: - Quick Look Lightbox Modal Overlay
            if isShowingQuickLook, let item = selectedItem {
                quickLookModal(for: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .confirmationDialog(
            "Clear unpinned items from history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Unpinned History", role: .destructive) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    manager.clearHistory(includingPinned: false)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            isSearchFieldFocused = true
            if selectedItemId == nil, let first = items.first {
                selectedItemId = first.id
            }
            startLocalKeyboardMonitoring()
        }
        .onDisappear {
            stopLocalKeyboardMonitoring()
        }
        .onChange(of: manager.searchText) { _, _ in
            if let first = items.first {
                selectedItemId = first.id
            } else {
                selectedItemId = nil
            }
        }
    }

    // MARK: - Search Header
    private var searchHeaderView: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isSearchFieldFocused ? .accentColor : .secondary)
                    .font(.system(size: 15, weight: .semibold))

                TextField("Search history, screenshots, files, links, code...", text: Bindable(manager).searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14.5, weight: .regular))
                    .focused($isSearchFieldFocused)

                if !manager.searchText.isEmpty {
                    Button {
                        manager.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSearchFieldFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.18),
                        lineWidth: 1
                    )
            )

            // Quick Settings Button
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")

            // Close Button
            Button {
                FloatingPanelController.shared.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
    }
    // MARK: - Filter Section
    private var filterSection: some View {
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

            Spacer()

            if manager.pinnedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("\(manager.pinnedCount) pinned")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Left Item List Pane
    private var itemListPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(items.prefix(120).enumerated()), id: \.element.id) { index, item in
                        HUDItemRow(
                            item: item,
                            storage: manager.storage,
                            index: index,
                            isSelected: selectedItem?.id == item.id,
                            isHovered: hoveredItemId == item.id,
                            onSelect: {
                                selectedItemId = item.id
                            },
                            onPaste: {
                                pasteItem(item)
                            },
                            onQuickLook: {
                                selectedItemId = item.id
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                    isShowingQuickLook = true
                                }
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
                .padding(8)
            }
            .onChange(of: selectedItemId) { _, newId in
                if let newId = newId {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Right Detail Preview Pane
    private var detailPreviewPane: some View {
        Group {
            if let item = selectedItem {
                VStack(alignment: .leading, spacing: 10) {
                    // Header metadata bar
                    HStack(spacing: 8) {
                        AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.sourceAppName ?? item.contentType.rawValue.capitalized)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(formattedDateTime(item.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        MetadataPill(text: item.contentType.rawValue.uppercased(), systemImage: item.systemImageName, iconColor: .accentColor)

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                    }

                    Divider()
                        .opacity(0.25)

                    // Content preview based on type
                    detailBodyView(for: item)

                    Spacer()

                    Divider()
                        .opacity(0.25)

                    // Detail Action Toolbar
                    detailFooterView(for: item)
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select an item to view preview")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Detail Body Views
    @ViewBuilder
    private func detailBodyView(for item: ClipboardItem) -> some View {
        switch item.contentType {
        case .image:
            if let fileName = item.imageFileName, let image = manager.storage.loadImage(for: fileName) {
                VStack(spacing: 10) {
                    // Image Stage
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.28))
                            .overlay(
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(8)
                            )
                            .frame(maxWidth: .infinity, maxHeight: 230)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)

                        // Quick Look Badge Button
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                isShowingQuickLook = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text("Space to Zoom")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }

                    // Metadata Pill Badges
                    HStack(spacing: 8) {
                        if let w = item.imageWidth, let h = item.imageHeight {
                            MetadataPill(text: "\(Int(w)) × \(Int(h)) px", systemImage: "aspectratio", iconColor: .blue)
                        }
                        if let size = item.imageByteSize {
                            MetadataPill(text: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), systemImage: "internaldrive", iconColor: .green)
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            } else {
                Text("Image data not available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .file:
            if let files = item.filePaths {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(files.count) File\(files.count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(files, id: \.self) { path in
                                HStack(spacing: 10) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                        .resizable()
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text(URL(fileURLWithPath: path).deletingLastPathComponent().path)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                                       let size = attrs[.size] as? Int64 {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }

        case .text, .code, .url, .rtf:
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.textContent ?? "")
                        .font(.system(size: 12.5, design: item.contentType == .code ? .monospaced : .default))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 0.75)
                        )
                }
            }
        }
    }

    // MARK: - Detail Footer
    @ViewBuilder
    private func detailFooterView(for item: ClipboardItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if item.contentType == .image {
                    Text("Screenshot / Image")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                } else if item.contentType == .file {
                    Text("\(item.filePaths?.count ?? 0) file(s) selected")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(item.characterCount) chars · \(item.lineCount) lines")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if item.contentType == .image, let fileName = item.imageFileName {
                Button {
                    let url = manager.storage.imageURL(for: fileName)
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10.5))
                        Text("Preview")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.secondary.opacity(0.14))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            if item.contentType == .file, let files = item.filePaths, !files.isEmpty {
                Button {
                    let urls = files.map { URL(fileURLWithPath: $0) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 10.5))
                        Text("Finder")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(Color.secondary.opacity(0.14))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Interactive Action Buttons Footer Bar
    private var interactiveFooterBar: some View {
        HStack(spacing: 7) {
            // 1. Primary Paste Button
            Button {
                if let item = selectedItem {
                    pasteItem(item)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Paste")
                        .font(.system(size: 12, weight: .semibold))
                    KeycapBadge(text: "↵", isAccent: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .disabled(selectedItem == nil)

            // 2. Quick Look Button
            Button {
                if selectedItem != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        isShowingQuickLook.toggle()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "eye")
                        .font(.system(size: 10.5))
                    Text("Preview")
                        .font(.system(size: 11.5, weight: .medium))
                    KeycapBadge(text: "Space")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedItem == nil)

            // 3. Pin / Unpin Button
            Button {
                if let item = selectedItem {
                    manager.togglePin(item)
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: (selectedItem?.isPinned ?? false) ? "pin.fill" : "pin")
                        .font(.system(size: 10.5))
                        .foregroundColor((selectedItem?.isPinned ?? false) ? .orange : .primary)
                    Text((selectedItem?.isPinned ?? false) ? "Unpin" : "Pin")
                        .font(.system(size: 11.5, weight: .medium))
                    KeycapBadge(text: "⌘P")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedItem == nil)

            // 4. Delete Button
            Button {
                if let item = selectedItem {
                    manager.deleteItem(item)
                    if let first = items.first {
                        selectedItemId = first.id
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 10.5))
                    Text("Delete")
                        .font(.system(size: 11.5, weight: .medium))
                    KeycapBadge(text: "⌘⌫")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedItem == nil)

            Spacer()

            // 5. Settings Button
            Button {
                openSettings()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10.5))
                    Text("Settings")
                        .font(.system(size: 11.5, weight: .medium))
                    KeycapBadge(text: "⌘,")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")

            // 6. Clear History Button
            Button {
                showingClearConfirmation = true
            } label: {
                Image(systemName: "trash.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Clear Unpinned History")
        }
    }

    // MARK: - Lightbox Modal
    @ViewBuilder
    private func quickLookModal(for item: ClipboardItem) -> some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        isShowingQuickLook = false
                    }
                }

            VStack(spacing: 12) {
                // Header
                HStack {
                    AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 20)
                    Text(item.previewTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            isShowingQuickLook = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Body Image / File Content
                if item.contentType == .image, let fileName = item.imageFileName, let image = manager.storage.loadImage(for: fileName) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 660, maxHeight: 390)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: Color.black.opacity(0.5), radius: 16)
                } else if item.contentType == .file, let files = item.filePaths {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(files, id: \.self) { path in
                            HStack(spacing: 12) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(URL(fileURLWithPath: path).lastPathComponent)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text(path)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: 620)
                    .padding()
                } else {
                    ScrollView {
                        Text(item.textContent ?? "")
                            .font(.system(size: 13, design: item.contentType == .code ? .monospaced : .default))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(maxWidth: 620, maxHeight: 300)
                }

                // Footer
                HStack(spacing: 12) {
                    Text("Press Space or Esc to close · Enter to paste")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Button {
                        isShowingQuickLook = false
                        pasteItem(item)
                    } label: {
                        Text("Paste Now")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.96))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 32, x: 0, y: 16)
            .frame(maxWidth: 700, maxHeight: 470)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No clipboard history found")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers & Actions
    private func pasteItem(_ item: ClipboardItem) {
        PasteService.shared.restoreAndPaste(item: item, manager: manager, autoPaste: true)
    }

    private func openSettings() {
        FloatingPanelController.shared.hide()
        SettingsWindowController.shared.show()
    }

    private func selectNext() {
        guard !items.isEmpty else { return }
        guard let currentId = selectedItemId, let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = items.first?.id
            return
        }
        let nextIndex = min(currentIndex + 1, items.count - 1)
        selectedItemId = items[nextIndex].id
    }

    private func selectPrevious() {
        guard !items.isEmpty else { return }
        guard let currentId = selectedItemId, let currentIndex = items.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = items.first?.id
            return
        }
        let prevIndex = max(currentIndex - 1, 0)
        selectedItemId = items[prevIndex].id
    }

    private func startLocalKeyboardMonitoring() {
        stopLocalKeyboardMonitoring()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape
            if event.keyCode == 53 {
                if isShowingQuickLook {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        isShowingQuickLook = false
                    }
                    return nil
                } else {
                    FloatingPanelController.shared.hide()
                    return nil
                }
            }

            // Spacebar (keyCode 49): Toggle Quick Look
            if event.keyCode == 49 {
                if !isSearchFieldFocused || manager.searchText.isEmpty {
                    if selectedItem != nil {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            isShowingQuickLook.toggle()
                        }
                        return nil
                    }
                }
            }

            // If Quick Look is open, Enter pastes
            if isShowingQuickLook && event.keyCode == 36 {
                if let item = selectedItem {
                    isShowingQuickLook = false
                    pasteItem(item)
                }
                return nil
            }

            // Arrow Down
            if event.keyCode == 125 {
                selectNext()
                return nil
            }
            // Arrow Up
            if event.keyCode == 126 {
                selectPrevious()
                return nil
            }
            // Enter / Return
            if event.keyCode == 36 {
                if let item = selectedItem {
                    pasteItem(item)
                }
                return nil
            }
            // Command + Number (⌘1 .. ⌘9)
            if event.modifierFlags.contains(.command), let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1, num <= 9 {
                let targetIndex = num - 1
                if targetIndex < items.count {
                    pasteItem(items[targetIndex])
                    return nil
                }
            }
            // Command + P (Toggle Pin)
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "p" {
                if let item = selectedItem {
                    manager.togglePin(item)
                }
                return nil
            }
            // Command + Backspace (Delete)
            if event.modifierFlags.contains(.command), event.keyCode == 51 {
                if let item = selectedItem {
                    manager.deleteItem(item)
                    if let first = items.first {
                        selectedItemId = first.id
                    }
                }
                return nil
            }
            // Command + Comma (⌘, Open Settings)
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
                openSettings()
                return nil
            }

            return event
        }
    }

    private func stopLocalKeyboardMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - HUD Item Row with High-Res Thumbnail, App Icons, and Hover Actions
struct HUDItemRow: View {
    let item: ClipboardItem
    let storage: StorageService
    let index: Int
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onQuickLook: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                // Quick shortcut indicator (1..9)
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.55))
                        .frame(width: 12)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                // Visual Icon / High-Res Thumbnail
                leadingItemVisual

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.previewTitle)
                        .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 12)

                        if let app = item.sourceAppName {
                            Text(app)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.85))
                        }

                        if let sec = item.secondaryPreview {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(sec)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Actions on hover or pin badge
                if isHovered {
                    HStack(spacing: 3) {
                        Button(action: onQuickLook) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Preview (Space)")

                        Button(action: onTogglePin) {
                            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 10))
                                .foregroundColor(item.isPinned ? .orange : .secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Unpin" : "Pin (⌘P)")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Delete (⌘⌫)")
                    }
                } else if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onPaste()
            }
        )
        .contextMenu {
            Button("Paste (↵)") {
                onPaste()
            }
            Button("Quick Look (Space)") {
                onQuickLook()
            }
            Divider()
            Button(item.isPinned ? "Unpin (⌘P)" : "Pin to Top (⌘P)") {
                onTogglePin()
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
            Button("Delete (⌘⌫)", role: .destructive) {
                onDelete()
            }
        }
    }

    @ViewBuilder
    private var leadingItemVisual: some View {
        if item.contentType == .image, let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 2.5, x: 0, y: 1.5)
        } else if item.contentType == .file, let files = item.filePaths, let first = files.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                .resizable()
                .frame(width: 26, height: 26)
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}
