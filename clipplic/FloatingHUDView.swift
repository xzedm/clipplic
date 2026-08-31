//
//  FloatingHUDView.swift
//  clipplic
//

import SwiftUI
import QuickLook

struct FloatingHUDView: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var selectedItemId: UUID? = nil
    @State private var isShowingQuickLook: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var localKeyMonitor: Any? = nil

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
                // MARK: - Search Header
                searchHeaderView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Divider()
                    .opacity(0.4)

                // MARK: - Main Dual-Pane Content
                if items.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(spacing: 0) {
                        // Left list (46% width)
                        itemListPane
                            .frame(width: 320)

                        Divider()
                            .opacity(0.3)

                        // Right detail preview pane (54% width)
                        detailPreviewPane
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                Divider()
                    .opacity(0.4)

                // MARK: - Shortcuts Footer Bar
                footerShortcutsBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .frame(width: 720, height: 490)
            .background(HUDVisualEffectView().ignoresSafeArea())
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)

            // MARK: - Quick Look Lightbox Modal Overlay
            if isShowingQuickLook, let item = selectedItem {
                quickLookModal(for: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
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
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Search history, screenshots, files, links, code...", text: Bindable(manager).searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isSearchFieldFocused)

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            Text("ESC to close")
                .font(.system(size: 10.5, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
                .foregroundColor(.secondary)
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
                            onSelect: {
                                selectedItemId = item.id
                            },
                            onPaste: {
                                pasteItem(item)
                            },
                            onQuickLook: {
                                selectedItemId = item.id
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    isShowingQuickLook = true
                                }
                            }
                        )
                        .id(item.id)
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
                        Image(systemName: item.systemImageName)
                            .foregroundColor(.accentColor)
                            .font(.system(size: 13, weight: .semibold))

                        Text(item.contentType.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }

                        if let app = item.sourceAppName {
                            Text(app)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()
                        .opacity(0.3)

                    // Content preview based on type
                    detailBodyView(for: item)

                    Spacer()

                    Divider()
                        .opacity(0.3)

                    // Stats & Action Footer
                    detailFooterView(for: item)
                }
                .padding(12)
            } else {
                VStack {
                    Spacer()
                    Text("Select an item to view preview")
                        .font(.system(size: 12))
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
                    // Interactive Image Preview Card
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 240)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)

                        // Quick Look Badge Button
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                isShowingQuickLook = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 10))
                                Text("Space to Zoom")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                    }

                    // Metadata Pill Badges
                    HStack(spacing: 10) {
                        if let w = item.imageWidth, let h = item.imageHeight {
                            Label("\(Int(w)) × \(Int(h)) px", systemImage: "aspectratio")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                                .foregroundColor(.primary)
                        }
                        if let size = item.imageByteSize {
                            Label(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), systemImage: "internaldrive")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(6)
                                .foregroundColor(.primary)
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
                Text(item.textContent ?? "")
                    .font(.system(size: 12, design: item.contentType == .code ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
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
                Text("Copied \(formattedDateTime(item.createdAt))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            // Quick Actions based on type
            if item.contentType == .image, let fileName = item.imageFileName {
                Button {
                    let url = manager.storage.imageURL(for: fileName)
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                        Text("Preview")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            if item.contentType == .file, let files = item.filePaths, !files.isEmpty {
                Button {
                    let urls = files.map { URL(fileURLWithPath: $0) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                        Text("Finder")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Button {
                pasteItem(item)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Paste")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Lightbox Modal
    @ViewBuilder
    private func quickLookModal(for item: ClipboardItem) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isShowingQuickLook = false
                    }
                }

            VStack(spacing: 12) {
                // Header
                HStack {
                    Text(item.previewTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            isShowingQuickLook = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
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
                        .frame(maxWidth: 620, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 12)
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
                    .frame(maxWidth: 600)
                    .padding()
                } else {
                    ScrollView {
                        Text(item.textContent ?? "")
                            .font(.system(size: 13, design: item.contentType == .code ? .monospaced : .default))
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(maxWidth: 600, maxHeight: 300)
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
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            .frame(maxWidth: 660, maxHeight: 440)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No clipboard history found")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Footer Shortcuts Bar
    private var footerShortcutsBar: some View {
        HStack(spacing: 10) {
            ShortcutHint(key: "↵", label: "Paste")
            ShortcutHint(key: "Space", label: "Quick Look")
            ShortcutHint(key: "⌘1..9", label: "Quick Paste")
            ShortcutHint(key: "⌘P", label: "Pin")
            ShortcutHint(key: "⌘⌫", label: "Delete")
            ShortcutHint(key: "⌘,", label: "Settings")

            Spacer()

            Text("\(items.count) items")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: - Helpers & Actions
    private func pasteItem(_ item: ClipboardItem) {
        PasteService.shared.restoreAndPaste(item: item, manager: manager, autoPaste: true)
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
            // Escape: if Quick Look is open, close Quick Look; else close HUD
            if event.keyCode == 53 {
                if isShowingQuickLook {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
                // If search text field is focused and not empty, don't hijack unless user pressed Option or Shift
                if !isSearchFieldFocused || manager.searchText.isEmpty {
                    if selectedItem != nil {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
                FloatingPanelController.shared.hide()
                SettingsWindowController.shared.show()
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

// MARK: - HUD Item Row with High-Res Thumbnail
struct HUDItemRow: View {
    let item: ClipboardItem
    let storage: StorageService
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onQuickLook: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Quick shortcut indicator (1..9)
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
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

                    if let sec = item.secondaryPreview {
                        Text(sec)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
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
        }
    }

    @ViewBuilder
    private var leadingItemVisual: some View {
        if item.contentType == .image, let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 38, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        } else if item.contentType == .file, let files = item.filePaths, let first = files.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: first))
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 24, height: 24)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(5)
        }
    }
}

// MARK: - Shortcut Hint Pill
struct ShortcutHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(3)
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - HUD Visual Effect View (Frosted Glass)
struct HUDVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
