# 🍎 Clipplic — Native macOS Clipboard Manager

> **A fast, lightweight, privacy-first clipboard manager handcrafted for macOS using Swift, SwiftUI, and AppKit.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?logo=apple&style=flat-square)](#)
[![Language](https://img.shields.io/badge/Swift-6.0%20%2F%20SwiftUI-orange?logo=swift&style=flat-square)](#)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](#)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local--First-success?style=flat-square)](#)

---

## 🌟 Overview

**Clipplic** is a modern, native macOS clipboard manager designed to live quietly in your menu bar and trigger instantly with a global hotkey (**`⌘ + Shift + V`**). It offers a Spotlight-style HUD, automatic screenshot capture, Finder file support, live Quick Look preview, and robust privacy exclusions for sensitive apps.

### Core Principles

* 🔒 **100% Local-First:** No cloud upload, no analytics, no network telemetry, no external servers.
* ⚡ **Ultra-Lightweight:** 0.0% idle CPU usage and under 25 MB RAM.
* 🍎 **Pure macOS Native:** Handcrafted with SwiftUI, AppKit (`NSPasteboard`), Carbon Hotkeys, and `ServiceManagement`.
* 🛡️ **Privacy by Design:** Automatically detects and filters password managers and sensitive credentials.

---

## ✨ Key Features

### 1. 🚀 Global Spotlight HUD (`⌘ + Shift + V`)
* Trigger an ultra-responsive, floating Spotlight-style overlay from **any application** (VS Code, Chrome, Terminal, Slack, etc.).
* **Keyboard-First Workflow:** Navigate with `↑` / `↓`, quick-paste top items with `⌘1`–`⌘9`, toggle pin with `⌘P`, delete with `⌘⌫`, and dismiss with `Esc`.
* **Hardware-Style Keycap Badges:** Visual Apple Magic Keyboard keycap pills for quick reference.

### 2. ⚡ Auto-Paste Simulation
* Press **`Enter`** on any item to automatically restore it to the clipboard, refocus your previous application, and paste directly into your active text field via synthetic `⌘V` keystrokes.

### 3. 🖼️ Screenshots & Rich Media Support
* **Full Image Support:** Captures PNG, TIFF, and clipboard image data.
* **Automated Screenshot Watcher:** Automatically detects and captures screenshots created with `⌘⇧3` and `⌘⇧4` into your history without needing to manually copy them.
* **Fast Screenshot Paste (Instant `⌘V`):** Newly captured screenshots are automatically copied to the system clipboard in universal formats (`public.png`, `public.tiff`, and file URL). You can immediately press **`⌘V`** in Telegram, Slack, Discord, Chrome, Figma, or Notes to paste the screenshot without touching `⌘⇧V`.
* **Aspect-Fit Thumbnails:** Crisp $40 \times 30\text{pt}$ card thumbnails in the list and a dark-velvet staging viewer in the detail pane.

### 4. 👁️ Spacebar Quick Look Lightbox
* Tap **`Spacebar`** on any highlighted image or file item to launch an instant full-resolution Quick Look lightbox modal.
* Displays image geometry ($W \times H\text{ px}$), exact file sizes, and file system paths.

### 5. 📁 Finder Files & Multi-File Selections
* Copying files or folders in Finder records their file URLs and native macOS file icons.
* Detail pane lists individual file sizes, parent directory paths, and includes a **"Reveal in Finder"** quick action.

### 6. 🔍 Real-Time Search & Category Filters
* Instant case-insensitive search across text contents, URLs, code snippets, file paths, and source app names.
* Clickable filter pills: **All**, **Images**, **Files**, **Text**, **Links**, and **Code**.

### 7. 🛡️ Privacy Controls & App Blacklisting
* **Password Manager Protection:** Automatically skips passwords and transient tokens from 1Password, Bitwarden, KeePassXC, and Apple Keychain.
* **Ignored Applications Blacklist:** Exclude specific applications (e.g., Terminal, iTerm2) so sensitive commands or tokens are never recorded.

### 8. 💾 Storage Management & Retention Rules
* Configurable history limits ($100$, $300$, $500$, $1,000$, or $5,000$ items).
* Auto-delete unpinned items older than $7\text{ days}$, $30\text{ days}$, $90\text{ days}$, or $1\text{ year}$.
* Pinned items (`isPinned = true`) are permanent and never auto-deleted.
* In-memory `NSCache` with a 50 MB hard ceiling for zero-latency image decoding and automatic memory purging under system pressure.

### 9. 🚀 Launch at Login
* Native macOS `SMAppService` integration configurable with one click in Settings.

---

## 📦 Installation & macOS Security

### 1. Download & Install
Download the latest release and drag **`Clipplic.app`** into your `/Applications` folder.

### 2. Allowing the App to Run (Gatekeeper & Security Settings)
Because Clipplic is an open-source application distributed outside the Mac App Store, macOS may block it on first launch with a warning such as:
> *"Clipplic cannot be opened because Apple cannot check it for malicious software"* or *"unidentified developer"*.

**To allow Clipplic to open:**
1. Open **System Settings** ( > **System Settings...**).
2. Go to **Privacy & Security** in the sidebar.
3. Scroll down to the **Security** section.
4. Look for the message: *"Clipplic was blocked from use because it is not from an identified developer"*.
5. Click **Open Anyway** and confirm with your password or Touch ID.
6. Click **Open** in the alert dialog.

> [!TIP]
> **Alternative Quick Open:** Right-click (or `Control`-click) **`Clipplic.app`** in Finder, choose **Open** from the context menu, and click **Open** in the confirmation dialog.
>
> **Terminal Bypass:** You can also remove the quarantine flag via Terminal:
> ```bash
> xattr -cr /Applications/Clipplic.app
> ```

### 3. Accessibility Permissions (Required for Auto-Paste)
To allow Clipplic to automatically paste (`⌘V`) items directly into your active apps:
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Ensure **Clipplic** is toggled **ON**.

---

## ⌨️ Keyboard Shortcuts Reference

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| **`⌘ + Shift + V`** | Open / Toggle Floating Spotlight HUD | Global (Any App) |
| **`↑` / `↓`** | Select Previous / Next Item | Floating HUD |
| **`↵` (Return)** | Paste Selected Item into Active App | Floating HUD |
| **`Space`** | Open / Close Quick Look Lightbox Preview | Floating HUD |
| **`⌘1` .. `⌘9`** | Quick-Paste Items 1 through 9 | Floating HUD |
| **`⌘P`** | Pin / Unpin Selected Item | Floating HUD |
| **`⌘⌫` (Backspace)** | Delete Selected Item | Floating HUD |
| **`⌘,`** | Open Preferences / Settings Window | Floating HUD / Menu Bar |
| **`Esc`** | Dismiss Quick Look / Close Floating HUD | Floating HUD |

---

## 🏗️ Architecture & Tech Stack

### Building the installer DMG

Export the Release `.app` from Xcode, then package it on macOS:

```bash
python3 -m venv build/dmg-tools
build/dmg-tools/bin/python -m pip install -r packaging/requirements.txt
build/dmg-tools/bin/python packaging/build_dmg.py /path/to/clipplic.app
```

The output is `build/Clipplic-<app-version>.dmg`. Use `--output /path/to/new-name.dmg`
to choose another filename. Existing output files are never overwritten.

Always use this script for release DMGs: it embeds a 560 × 320 Finder window,
80-point icons, and fixed app/Applications positions in the image's `.DS_Store`.
The installer artwork includes a drag arrow and Retina resolution. To update it,
edit `packaging/render_background.swift` and run
`swift packaging/render_background.swift packaging` before packaging again.

```
┌─────────────────────────────────────────────────────────────┐
│                 UI Layer (SwiftUI + AppKit)                 │
│  • MenuBarExtra (Native macOS Status Bar Menu)              │
│  • FloatingPanel (Custom NSPanel Floating HUD)              │
│  • SettingsView (Multi-Tab Preferences Window)              │
└──────────────────────────────▲──────────────────────────────┘
                               │ (@Observable / Swift 6)
┌──────────────────────────────┴──────────────────────────────┐
│                  ClipboardManager (State)                   │
│  • In-memory history, deduplication, search indexing        │
│  • Write-back to NSPasteboard, pin & retention control      │
└──────────────▲───────────────▲───────────────▲──────────────┘
               │               │               │
┌──────────────┴──────────┐ ┌──┴───────────┐ ┌─┴──────────────┐
│    ClipboardMonitor     │ │StorageService│ │ HotkeyManager  │
│ • NSPasteboard polling  │ │ • JSON Store │ │ • Carbon API   │
│ • Privacy filter        │ │ • Disk Image │ │ • ⌘⇧V Listener │
│ • ScreenshotWatcher     │ │   Cache      │ │                │
└─────────────────────────┘ └──────────────┘ └────────────────┘
```

### Decoupled Subsystems:
* **`ClipboardItem.swift`:** Codable data model supporting Text, URL, Code, RTF, Image, and File types with SHA-256 deduplication hashing.
* **`ClipboardMonitor.swift`:** Sub-millisecond timer polling of `NSPasteboard.general.changeCount` with self-write suppression.
* **`ScreenshotWatcher.swift`:** `DispatchSourceFileSystemObject` directory monitor tracking desktop screenshot outputs.
* **`StorageService.swift`:** Atomic local JSON persistence (`~/Library/Application Support/clipplic/history.json`) and isolated image cache (`clipplic/images/`).
* **`HotkeyManager.swift`:** Native Carbon `RegisterEventHotKey` listener for instant global activation without accessibility prompts for shortcut triggering.
* **`PasteService.swift`:** App activation manager and `CGEvent` keyboard event synthesizer for automated `⌘V` pasting.
* **`PreferencesService.swift`:** `UserDefaults` state coordinator with `SMAppService` launch-at-login integration.

---

## 📂 Project Structure

```
clipplic/
├── clipplicApp.swift              # App entry point, MenuBarExtra scene & AppDelegate
├── ContentView.swift              # Menu bar popover interface (Search, List, Actions)
├── FloatingHUDView.swift          # Spotlight HUD dual-pane interface & Lightbox modal
├── FloatingPanelController.swift  # Floating NSPanel window management
├── ClipboardManager.swift         # Main Observable coordinator
├── ClipboardMonitor.swift         # NSPasteboard observer & sensitive data filters
├── ScreenshotWatcher.swift        # Background folder watcher for macOS screenshots
├── StorageService.swift           # Local JSON persistence & image cache
├── PasteService.swift             # CGEvent auto-paste simulation & target app focus
├── HotkeyManager.swift            # Carbon global hotkey listener (⌘⇧V)
├── PreferencesService.swift       # Settings state, App exclusions & SMAppService
├── SettingsView.swift             # Multi-tab native Settings interface
├── SettingsWindowController.swift # Settings NSWindow lifecycle controller
├── UIComponents.swift             # AppIconView, KeycapBadge, MetadataPill, Glass backgrounds
└── ClipboardItem.swift            # Core data model & content type representations
```

---

## 📊 Performance & System Impact

* **Idle CPU:** $\approx 0.0001\%$ (Effectively **0.0%**).
* **Idle Memory:** $\approx 18 - 28\text{ MB}$ RAM.
* **Image Memory Cache:** Capped at $50\text{ MB}$ with automatic system memory pressure purging.
* **Binary Size:** Compact native binary ($< 5\text{ MB}$) with zero external framework dependencies.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE.md) file for details.
