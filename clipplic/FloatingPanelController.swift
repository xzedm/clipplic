//
//  FloatingPanelController.swift
//  clipplic
//

import AppKit
import SwiftUI

public final class FloatingPanel: NSPanel {
    override public var canBecomeKey: Bool {
        true
    }

    override public var canBecomeMain: Bool {
        true
    }
}

@MainActor
public final class FloatingPanelController: NSObject, NSWindowDelegate {
    public static let shared = FloatingPanelController()

    private var panel: FloatingPanel?
    private var isVisible: Bool = false
    private var globalClickMonitor: Any?

    public var onDismiss: (() -> Void)?

    private override init() {
        super.init()
    }

    public func setup<Content: View>(rootView: Content, width: CGFloat = 600, height: CGFloat = 460) {
        if panel != nil { return }

        let customPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        customPanel.isFloatingPanel = true
        customPanel.level = .floating
        customPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        customPanel.titleVisibility = .hidden
        customPanel.titlebarAppearsTransparent = true
        customPanel.isMovableByWindowBackground = true
        customPanel.isReleasedWhenClosed = false
        customPanel.backgroundColor = .clear
        customPanel.isOpaque = false
        customPanel.hasShadow = true
        customPanel.delegate = self

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        customPanel.contentView = hostingView

        self.panel = customPanel
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard let panel = panel else { return }

        positionCenterUpper(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        startMonitoringOutsideClicks()
    }

    public func hide() {
        guard let panel = panel, isVisible else { return }
        stopMonitoringOutsideClicks()
        panel.orderOut(nil)
        isVisible = false
        onDismiss?()
    }

    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func positionCenterUpper(_ window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            window.center()
            return
        }

        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame

        // Place horizontally centered, vertically in upper 38% of screen (Spotlight-style)
        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) * 0.65

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func startMonitoringOutsideClicks() {
        stopMonitoringOutsideClicks()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
