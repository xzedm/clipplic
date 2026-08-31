//
//  UIComponents.swift
//  clipplic
//

import AppKit
import SwiftUI

// MARK: - Native macOS App Icon View
struct AppIconView: View {
    let bundleID: String?
    let appName: String?
    var size: CGFloat = 18

    var body: some View {
        if let icon = resolvedAppIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 0.5)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.7))
                .foregroundColor(.secondary)
                .frame(width: size, height: size)
        }
    }

    private var resolvedAppIcon: NSImage? {
        if let bundleID = bundleID,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        if let appName = appName {
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
                return running.icon
            }
        }

        return nil
    }
}

// MARK: - Apple-Style Keycap Badge
struct KeycapBadge: View {
    let text: String
    var isAccent: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(isAccent ? .white : .primary.opacity(0.85))
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isAccent
                                ? [Color.white.opacity(0.25), Color.white.opacity(0.12)]
                                : [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(
                        isAccent
                            ? Color.white.opacity(0.35)
                            : Color.white.opacity(0.22),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Metadata Chip Pill
struct MetadataPill: View {
    let text: String
    var systemImage: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(iconColor)
            }
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Vibrant Frosted Glass Backgrounds with Rounded Masking
struct HUDGlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 16

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.layer?.cornerRadius = cornerRadius
    }
}

struct PopoverGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
