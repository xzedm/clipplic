//
//  FloatingHUDView.swift
//  clipplic
//

import SwiftUI

struct FloatingHUDView: View {
    @Environment(ClipboardManager.self) private var manager
    @State private var selectedItemId: UUID? = nil
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
                    // Left list (52% width)
                    itemListPane
                        .frame(width: 320)

                    Divider()
                        .opacity(0.3)

                    // Right detail preview pane (48% width)
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
        .frame(width: 680, height: 460)
        .background(HUDVisualEffectView().ignoresSafeArea())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
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

            TextField("Search history, images, files, links, code...", text: Bindable(manager).searchText)
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
                LazyVStack(spacing: 3) {
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
                    // Header metadata
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
                VStack(spacing: 8) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(radius: 4)

                    HStack(spacing: 12) {
                        if let w = item.imageWidth, let h = item.imageHeight {
                            Label("\(Int(w)) × \(Int(h)) px", systemImage: "aspectratio")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if let size = item.imageByteSize {
                            Label(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file), systemImage: "internaldrive")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } else {
                Text("Image data not available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

        case .file:
            if let files = item.filePaths {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(files, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 20, height: 20)

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
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
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
                    Text("Copied image")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if item.contentType == .file {
                    Text("\(item.filePaths?.count ?? 0) file(s)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(item.characterCount) characters · \(item.lineCount) lines")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Text("Copied \(formattedDateTime(item.createdAt))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Spacer()

            if item.contentType == .file, let files = item.filePaths, let first = files.first {
                Button {
                    let urls = files.map { URL(fileURLWithPath: $0) }
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                } label: {
                    Text("Reveal in Finder")
                        .font(.system(size: 11))
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
        HStack(spacing: 12) {
            ShortcutHint(key: "↵", label: "Paste")
            ShortcutHint(key: "⌘1..9", label: "Quick Paste")
            ShortcutHint(key: "⌘P", label: "Pin")
            ShortcutHint(key: "⌘⌫", label: "Delete")

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
            // Escape
            if event.keyCode == 53 {
                FloatingPanelController.shared.hide()
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

// MARK: - HUD Item Row
struct HUDItemRow: View {
    let item: ClipboardItem
    let storage: StorageService
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Quick shortcut indicator (1..9)
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))
                        .frame(width: 14)
                } else {
                    Spacer()
                        .frame(width: 14)
                }

                // Visual Icon / Thumbnail
                leadingItemVisual

                // Title
                Text(item.previewTitle)
                    .font(.system(size: 12.5, weight: isSelected ? .medium : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)

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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
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
    }

    @ViewBuilder
    private var leadingItemVisual: some View {
        if item.contentType == .image, let fileName = item.imageFileName, let image = storage.loadImage(for: fileName) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: item.systemImageName)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .accentColor : .secondary)
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
