import AppKit
import Combine
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem!
    private weak var windowManager: WindowManager?

    // MARK: - Mode

    enum AppMode: String {
        case lyrics
        case aura
    }

    private(set) var currentMode: AppMode = .lyrics
    private let modeKey = "AuraLyricsAppMode"

    // Lock state (independent of mode)
    private var isLyricsLocked = false
    private var isAuraLocked = false

    // Visibility
    private var isWindowVisible = true

    // MARK: - Setup

    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager

        if let saved = UserDefaults.standard.string(forKey: modeKey),
           let mode = AppMode(rawValue: saved) {
            self.currentMode = mode
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "music.note.list",
                accessibilityDescription: "AuraLyrics"
            )
        }

        applyMode(currentMode)
        updateMenu()
    }

    // MARK: - Mode Management

    private func applyMode(_ mode: AppMode) {
        isWindowVisible = true
        switch mode {
        case .lyrics:
            windowManager?.toggleAuraWindow(visible: false)
            windowManager?.toggleLyricsWindow(visible: true)
        case .aura:
            windowManager?.toggleLyricsWindow(visible: false)
            windowManager?.toggleAuraWindow(visible: true)
        }
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
    }

    func hideWindows() {
        isWindowVisible = false
        windowManager?.toggleLyricsWindow(visible: false)
        windowManager?.toggleAuraWindow(visible: false)
        updateMenu()
    }

    func showCurrentWindow() {
        applyMode(currentMode)
        updateMenu()
    }

    func switchToAuraMode() {
        currentMode = .aura
        applyMode(.aura)
        updateMenu()
    }

    func switchToLyricsMode() {
        currentMode = .lyrics
        applyMode(.lyrics)
        updateMenu()
    }

    // MARK: - Menu Construction

    private func updateMenu() {
        let menu = NSMenu()

        // --- Controls ---
        let controlsItem = NSMenuItem()
        let hostingView = NSHostingView(rootView: MenuControlsView())
        hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 290)
        controlsItem.view = hostingView
        menu.addItem(controlsItem)

        menu.addItem(.separator())

        // --- Show / Hide ---
        if isWindowVisible {
            let item = NSMenuItem(
                title: "Hide Window",
                action: #selector(hideWindowsAction),
                keyEquivalent: "h"
            )
            item.target = self
            menu.addItem(item)
        } else {
            let title = currentMode == .lyrics ? "Show Lyrics View" : "Show Aura Mode"
            let item = NSMenuItem(title: title, action: #selector(showCurrentWindowAction), keyEquivalent: "s")
            item.target = self
            menu.addItem(item)
        }

        // --- Switch Mode ---
        if currentMode == .lyrics {
            let item = NSMenuItem(
                title: "Switch to Aura Mode",
                action: #selector(switchToAuraAction),
                keyEquivalent: "l"
            )
            item.target = self
            menu.addItem(item)
        } else {
            let item = NSMenuItem(
                title: "Return to Lyrics View",
                action: #selector(switchToLyricsAction),
                keyEquivalent: "l"
            )
            item.target = self
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // --- Theme ---
        let themeMenu = NSMenu()
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        for theme in AppTheme.allCases {
            let item = NSMenuItem(
                title: theme.rawValue,
                action: #selector(changeTheme(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = (ThemeManager.shared.currentTheme == theme) ? .on : .off
            item.representedObject = theme
            themeMenu.addItem(item)
        }

        // --- Aura Size ---
        let sizeMenu = NSMenu()
        let sizeItem = NSMenuItem(title: "Aura Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        sizeItem.isEnabled = (currentMode == .aura)
        menu.addItem(sizeItem)

        for size in AuraSize.allCases {
            let item = NSMenuItem(
                title: size.displayName,
                action: #selector(changeAuraSize(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = (AuraSizeManager.shared.currentSize == size) ? .on : .off
            item.representedObject = size
            sizeMenu.addItem(item)
        }

        menu.addItem(.separator())

        // --- Locking ---
        if currentMode == .lyrics {
            let title = isLyricsLocked ? "Unlock Lyrics View" : "Lock Lyrics View"
            let lockItem = NSMenuItem(title: title, action: #selector(toggleLockLyrics), keyEquivalent: "")
            lockItem.state = isLyricsLocked ? .on : .off
            lockItem.target = self
            lockItem.isEnabled = isWindowVisible
            menu.addItem(lockItem)
        } else {
            let title = isAuraLocked ? "Unlock Aura Mode" : "Lock Aura Mode"
            let lockItem = NSMenuItem(title: title, action: #selector(toggleLockAura), keyEquivalent: "")
            lockItem.state = isAuraLocked ? .on : .off
            lockItem.target = self
            lockItem.isEnabled = isWindowVisible
            menu.addItem(lockItem)
        }

        menu.addItem(.separator())

        // --- Quit ---
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// Schedules a deferred menu rebuild on the next run-loop cycle.
    ///
    /// Calling `updateMenu()` synchronously inside an `@objc` menu-item action
    /// replaces the NSMenu while it is still presented, which can crash.
    /// Deferring to the next cycle lets AppKit finish dismissing the menu first.
    private func deferredUpdateMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenu()
        }
    }

    // MARK: - Actions

    @objc private func showCurrentWindowAction() {
        showCurrentWindow()
    }

    @objc private func hideWindowsAction() {
        hideWindows()
    }

    @objc private func switchToLyricsAction() {
        switchToLyricsMode()
    }

    @objc private func switchToAuraAction() {
        switchToAuraMode()
    }

    @objc private func toggleLockLyrics() {
        isLyricsLocked.toggle()
        windowManager?.setLyricsWindowClickThrough(enabled: isLyricsLocked)
        deferredUpdateMenu()
    }

    @objc private func toggleLockAura() {
        isAuraLocked.toggle()
        windowManager?.setAuraWindowClickThrough(enabled: isAuraLocked)
        deferredUpdateMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? AppTheme else { return }
        ThemeManager.shared.setTheme(theme)
        deferredUpdateMenu()
    }

    @objc private func changeAuraSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? AuraSize else { return }
        AuraSizeManager.shared.setSize(size)
        deferredUpdateMenu()
    }
}
