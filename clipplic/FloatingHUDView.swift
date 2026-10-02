//
//  FloatingHUDView.swift
//  clipplic
//

import SwiftUI

struct FloatingHUDView: View {
    static let panelWidth: CGFloat = 560
    static let expandedPanelWidth: CGFloat = 860
    static let panelHeight: CGFloat = 460

    @Environment(ClipboardManager.self) private var manager
    @State private var selectedItemId: UUID?
    @State private var isShowingQuickLook = false
    @State private var isExpanded = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var localKeyMonitor: Any?
    @State private var hoveredItemId: UUID?
    @State private var showingClearConfirmation = false

    private var items: [ClipboardItem] { manager.filteredItems }

    private var selectedItem: ClipboardItem? {
        items.first(where: { $0.id == selectedItemId }) ?? items.first
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            filterBar
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.5)

            Group {
                if isShowingQuickLook, let item = selectedItem {
                    previewPane(for: item)
                } else if items.isEmpty {
                    emptyState
                } else if isExpanded, let item = selectedItem {
                    HStack(spacing: 0) {
                        itemList
                            .frame(width: 360)
                        Divider().opacity(0.5)
                        previewPane(for: item)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    itemList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.5)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: isExpanded ? Self.expandedPanelWidth : Self.panelWidth, height: Self.panelHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .confirmationDialog(
            "Clear unpinned items from history?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Unpinned History", role: .destructive) {
                manager.clearHistory(includingPinned: false)
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            isSearchFieldFocused = true
            selectedItemId = selectedItem?.id
            startLocalKeyboardMonitoring()
        }
        .onDisappear { stopLocalKeyboardMonitoring() }
        .onChange(of: isExpanded) { _, expanded in
            FloatingPanelController.shared.setWidth(expanded ? Self.expandedPanelWidth : Self.panelWidth)
        }
        .onChange(of: manager.searchText) { _, _ in
            selectedItemId = items.first?.id
            isShowingQuickLook = false
        }
        .onChange(of: manager.selectedTypeFilter) { _, _ in
            selectedItemId = items.first?.id
            isShowingQuickLook = false
        }
        .onChange(of: items.map(\.id)) { _, ids in
            if let selectedItemId, ids.contains(selectedItemId) { return }
            selectedItemId = ids.first
            if ids.isEmpty { isShowingQuickLook = false }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            TextField("Search clipboard", text: Bindable(manager).searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search clipboard history")

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                    isSearchFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button {
                isShowingQuickLook = false
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(isExpanded ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Switch to compact HUD" : "Expand HUD with automatic preview")
            .accessibilityLabel(isExpanded ? "Collapse HUD" : "Expand HUD with preview")
            .accessibilityValue(isExpanded ? "Expanded" : "Compact")

            actionsMenu
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            filterButton("All", systemImage: "square.grid.2x2", type: nil)
            filterButton("Images", systemImage: "photo", type: .image)
            filterButton("Files", systemImage: "folder", type: .file)
            filterButton("Text", systemImage: "doc.text", type: .text)
            filterButton("Links", systemImage: "link", type: .url)
            filterButton("Code", systemImage: "chevron.left.forwardslash.chevron.right", type: .code)
            filterButton("Rich text", systemImage: "textformat", type: .rtf)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter clipboard history")
    }

    private func filterButton(_ title: String, systemImage: String, type: ItemContentType?) -> some View {
        let isSelected = manager.selectedTypeFilter == type
        return Button {
            manager.selectedTypeFilter = type
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.75)
                }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(type == nil ? "Show all clipboard items" : "Show \(title.lowercased())")
    }

    private var actionsMenu: some View {
        Menu {
            if let item = selectedItem {
                Button(isShowingQuickLook ? "Close Preview (Space)" : "Preview (Space)") {
                    togglePreview()
                }
                Button(item.isPinned ? "Unpin (⌘P)" : "Pin (⌘P)") {
                    manager.togglePin(item)
                }
                Button("Delete (⌘⌫)", role: .destructive) { deleteItem(item) }
                Divider()
            }
            Button("Settings… (⌘,)") { openSettings() }
            Button("Clear Unpinned History…", role: .destructive) {
                showingClearConfirmation = true
            }
            .disabled(!manager.items.contains(where: { !$0.isPinned }))
            Divider()
            Button("Close (Esc)") { FloatingPanelController.shared.hide() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
        .accessibilityLabel("More actions")
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(items) { item in
                        HUDItemRow(
                            item: item,
                            storage: manager.storage,
                            isSelected: selectedItem?.id == item.id,
                            isHovered: hoveredItemId == item.id,
                            onSelect: {
                                selectedItemId = item.id
                                isSearchFieldFocused = false
                            },
                            onPaste: { pasteItem(item) },
                            onQuickLook: {
                                selectedItemId = item.id
                                togglePreview()
                            },
                            onTogglePin: { manager.togglePin(item) },
                            onDelete: { deleteItem(item) }
                        )
                        .id(item.id)
                        .onHover { hovering in
                            if hovering { hoveredItemId = item.id }
                            else if hoveredItemId == item.id { hoveredItemId = nil }
                        }
                    }
                }
                .padding(8)
            }
            .onChange(of: selectedItemId) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                togglePreview()
            } label: {
                Label(isShowingQuickLook ? "Back to history" : "Preview", systemImage: isShowingQuickLook ? "chevron.left" : "eye")
                    .padding(.horizontal, 6)
                    .frame(height: 28)
            }
            .buttonStyle(.bordered)
            .disabled(selectedItem == nil)
            .help(isShowingQuickLook ? "Back to history (Space or Esc)" : "Preview selected item (Space)")

            Button {
                if let item = selectedItem { manager.togglePin(item) }
            } label: {
                Label(selectedItem?.isPinned == true ? "Unpin" : "Pin", systemImage: selectedItem?.isPinned == true ? "pin.fill" : "pin")
                    .padding(.horizontal, 6)
                    .frame(height: 28)
            }
            .buttonStyle(.bordered)
            .disabled(selectedItem == nil)
            .help(selectedItem?.isPinned == true ? "Unpin selected item (⌘P)" : "Keep selected item in history (⌘P)")

            Spacer()

            Button {
                if let item = selectedItem { pasteItem(item) }
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
                .padding(.horizontal, 14)
                .frame(height: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItem == nil)
            .help("Paste selected item (Return)")
        }
        .font(.system(size: 12, weight: .medium))
    }

    private func previewPane(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 20)
                Text(item.sourceAppName ?? item.contentType.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(item.createdAt, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            previewContent(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
    }

    @ViewBuilder
    private func previewContent(for item: ClipboardItem) -> some View {
        switch item.contentType {
        case .image:
            if let fileName = item.imageFileName, let image = manager.storage.loadImage(for: fileName) {
                VStack(spacing: 12) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 12) {
                        if let width = item.imageWidth, let height = item.imageHeight {
                            Text("\(Int(width)) × \(Int(height)) px")
                        }
                        if let size = item.imageByteSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        }
                        Spacer()
                        Button("Open in Preview") { NSWorkspace.shared.open(manager.storage.imageURL(for: fileName)) }
                            .buttonStyle(.link)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("Image unavailable").foregroundStyle(.secondary)
            }
        case .file:
            if let files = item.filePaths, !files.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(files, id: \.self) { path in
                                HStack(spacing: 12) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                        .resizable()
                                        .frame(width: 28, height: 28)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                            .font(.system(size: 13, weight: .medium))
                                        Text(path)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(files.map { URL(fileURLWithPath: $0) })
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                }
            } else {
                Text("Files unavailable").foregroundStyle(.secondary)
            }
        case .text, .code, .url, .rtf:
            ScrollView {
                Text(previewText(for: item))
                    .font(.system(size: 14, design: item.contentType == .code ? .monospaced : .default))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: manager.items.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text(manager.items.isEmpty ? "Your clipboard starts here" : "No matching items")
                .font(.system(size: 14, weight: .medium))
            Text(manager.items.isEmpty ? "Copy something and it will appear here." : "Try another search or choose All.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func togglePreview() {
        guard selectedItem != nil else { return }
        isSearchFieldFocused = false
        withAnimation(.easeOut(duration: 0.12)) { isShowingQuickLook.toggle() }
    }

    private func deleteItem(_ item: ClipboardItem) {
        // Keep selection near the deleted row instead of jumping to the top.
        let index = items.firstIndex(where: { $0.id == item.id }) ?? 0
        manager.deleteItem(item)
        selectedItemId = items.isEmpty ? nil : items[min(index, items.count - 1)].id
        if items.isEmpty { isShowingQuickLook = false }
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
            // Only handle keys belonging to the HUD, not menus or confirmation dialogs.
            guard let window = event.window,
                  window === NSApp.keyWindow,
                  window is FloatingPanel,
                  !showingClearConfirmation else { return event }

            // Escape
            if event.keyCode == 53 {
                if isShowingQuickLook {
                    withAnimation(.easeOut(duration: 0.12)) {
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
                if isShowingQuickLook || !isSearchFieldFocused || manager.searchText.isEmpty {
                    if selectedItem != nil {
                        withAnimation(.easeOut(duration: 0.12)) {
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
                isSearchFieldFocused = false
                selectNext()
                return nil
            }
            // Arrow Up
            if event.keyCode == 126 {
                isSearchFieldFocused = false
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
            // Command + F returns to search.
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "f" {
                isShowingQuickLook = false
                isSearchFieldFocused = true
                return nil
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
                    deleteItem(item)
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

    /// Text shown in Quick Look: masks secrets and caps length so
    /// a multi-megabyte copy can't stall SwiftUI text layout.
    private func previewText(for item: ClipboardItem) -> String {
        if item.isSensitive && PreferencesService.shared.maskPasswordsInList {
            return "••••••••••••  (hidden — paste with ↵)"
        }
        let text = item.textContent ?? ""
        let limit = 20_000
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "\n\n… (\(text.count - limit) more characters — paste to see all)"
    }

    private func stopLocalKeyboardMonitoring() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

}

// MARK: - History Row
struct HUDItemRow: View {
    let item: ClipboardItem
    let storage: StorageService
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onQuickLook: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                leadingVisual
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.previewTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        if item.sourceAppBundleID != nil || item.sourceAppName != nil {
                            AppIconView(bundleID: item.sourceAppBundleID, appName: item.sourceAppName, size: 14)
                                .accessibilityHidden(true)
                        }
                        Text(item.sourceAppName ?? item.contentType.rawValue.capitalized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Pinned")
                }

            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .simultaneousGesture(TapGesture(count: 2).onEnded { onPaste() })
        .contextMenu {
            Button("Paste (↵)", action: onPaste)
            Button("Preview (Space)", action: onQuickLook)
            Button(item.isPinned ? "Unpin (⌘P)" : "Pin (⌘P)", action: onTogglePin)
            if item.contentType == .image, let fileName = item.imageFileName {
                Button("Open in Preview") { NSWorkspace.shared.open(storage.imageURL(for: fileName)) }
            }
            if item.contentType == .file, let files = item.filePaths, !files.isEmpty {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(files.map { URL(fileURLWithPath: $0) })
                }
            }
            Divider()
            Button("Delete (⌘⌫)", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if item.contentType == .image, let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
        } else if item.contentType == .file, let first = item.filePaths?.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                .resizable()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}
