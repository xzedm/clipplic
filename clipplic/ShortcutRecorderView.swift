//
//  ShortcutRecorderView.swift
//  clipplic
//

import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: View {
    @Bindable private var prefs = PreferencesService.shared
    @State private var isRecording: Bool = false
    @State private var keyMonitor: Any? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                            Text("Type shortcut...")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 1.5)
                        )
                    } else {
                        HStack(spacing: 4) {
                            ForEach(prefs.shortcut.keycapTokens, id: \.self) { token in
                                KeycapBadge(text: token)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Press your desired shortcut (or Esc to cancel)" : "Click to record custom global shortcut")

            if prefs.shortcut != HotkeyShortcut.defaultShortcut && !isRecording {
                Button {
                    prefs.shortcut = HotkeyShortcut.defaultShortcut
                } label: {
                    Text("Reset")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default (⌘⇧V)")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        stopRecordingMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc cancels recording if no modifiers
            if event.keyCode == 53 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                self.stopRecording()
                return nil
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbonMods = HotkeyShortcut.carbonModifiers(from: flags)

            // Must have at least one modifier key OR be a function key (F1-F12)
            let isFunctionKey = event.keyCode >= 120 && event.keyCode <= 122 || event.keyCode >= 96 && event.keyCode <= 101 || event.keyCode >= 109 && event.keyCode <= 111
            let hasModifiers = carbonMods != 0

            guard hasModifiers || isFunctionKey else {
                return nil
            }

            let newShortcut = HotkeyShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
            self.prefs.shortcut = newShortcut
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        stopRecordingMonitor()
    }

    private func stopRecordingMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
