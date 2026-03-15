import AppKit
import Combine
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem!
    private weak var windowManager: WindowManager?

    // Mode Management
    enum AppMode: String {
        case lyrics
        case aura
    }

    private(set) var currentMode: AppMode = .lyrics

    // State to track locks (independent of mode)
    private var isLyricsLocked = false
    private var isAuraLocked = false

    // Track visibility
    private var isWindowVisible = true

    // PERF-02: Stored NSMenuItem references — built once in buildMenu(), mutated in updateMenu()
    private var mainMenu: NSMenu!
    private var hideShowItem: NSMenuItem!
    private var modeSwitchItem: NSMenuItem!
    private var lockItem: NSMenuItem!
    private var themeItems: [AppTheme: NSMenuItem] = [:]
    private var sizeItems: [AuraSize: NSMenuItem] = [:]
    private var sizeMenuItem: NSMenuItem!

    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager

        // Load saved mode
        if let savedModeString = UserDefaults.standard.string(forKey: AppDefaults.Key.appMode.rawValue),
           let savedMode = AppMode(rawValue: savedModeString) {
            self.currentMode = savedMode
        } else {
            self.currentMode = .lyrics // Default
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "AuraLyrics")
        }

        // Apply initial state
        applyMode(currentMode)
        // PERF-02: build menu once; updateMenu() is called at the end of buildMenu() to populate state
        buildMenu()
    }

    private func applyMode(_ mode: AppMode) {
        // When applying a mode (switching or launch), we ensure it is visible
        isWindowVisible = true

        switch mode {
        case .lyrics:
            windowManager?.toggleAuraWindow(visible: false)
            windowManager?.toggleLyricsWindow(visible: true)
        case .aura:
            windowManager?.toggleLyricsWindow(visible: false)
            windowManager?.toggleAuraWindow(visible: true)
        }
        UserDefaults.standard.set(mode.rawValue, forKey: AppDefaults.Key.appMode.rawValue)
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

    // PERF-02: buildMenu() called ONCE from setup() — NSHostingView allocated exactly once here
    private func buildMenu() {
        mainMenu = NSMenu()

        // Controls — NSHostingView allocated ONCE here
        let controlsItem = NSMenuItem()
        controlsItem.view = {
            let hv = NSHostingView(rootView: MenuControlsView())
            // Frame matches the vertical layout size (Artwork 120 + Text + Controls + Padding)
            hv.frame = NSRect(x: 0, y: 0, width: 260, height: 290)
            return hv
        }()
        mainMenu.addItem(controlsItem)
        mainMenu.addItem(NSMenuItem.separator())

        // hideShowItem — title and action mutated in updateMenu()
        hideShowItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hideShowItem.target = self
        mainMenu.addItem(hideShowItem)

        // modeSwitchItem — title and action mutated in updateMenu()
        modeSwitchItem = NSMenuItem(title: "", action: nil, keyEquivalent: "l")
        modeSwitchItem.target = self
        mainMenu.addItem(modeSwitchItem)

        mainMenu.addItem(NSMenuItem.separator())

        // Theme submenu
        let themeMenu = NSMenu()
        let themeParent = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeParent.submenu = themeMenu
        mainMenu.addItem(themeParent)
        for theme in AppTheme.allCases {
            let item = NSMenuItem(title: theme.rawValue, action: #selector(changeTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme
            themeMenu.addItem(item)
            themeItems[theme] = item
        }

        // Size submenu
        let sizeMenu = NSMenu()
        sizeMenuItem = NSMenuItem(title: "Aura Size", action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeMenu
        mainMenu.addItem(sizeMenuItem)
        for size in AuraSize.allCases {
            let item = NSMenuItem(title: size.displayName, action: #selector(changeAuraSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size
            sizeMenu.addItem(item)
            sizeItems[size] = item
        }

        mainMenu.addItem(NSMenuItem.separator())

        // Lock item — title, action, and state mutated in updateMenu()
        lockItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        lockItem.target = self
        mainMenu.addItem(lockItem)

        mainMenu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        mainMenu.addItem(quitItem)

        statusItem.menu = mainMenu

        // Populate initial item state
        updateMenu()
    }

    // PERF-02: updateMenu() ONLY mutates stored NSMenuItem references — no NSHostingView allocation
    private func updateMenu() {
        // hideShowItem
        if !isWindowVisible {
            let title = currentMode == .lyrics ? "Show Lyrics View" : "Show Aura Mode"
            hideShowItem.title = title
            hideShowItem.action = #selector(showCurrentWindowAction)
            hideShowItem.keyEquivalent = "s"
        } else {
            hideShowItem.title = "Hide Window"
            hideShowItem.action = #selector(hideWindowsAction)
            hideShowItem.keyEquivalent = "h"
        }

        // modeSwitchItem
        if currentMode == .lyrics {
            modeSwitchItem.title = "Switch to Aura Mode"
            modeSwitchItem.action = #selector(switchToAuraAction)
        } else {
            modeSwitchItem.title = "Return to Lyrics View"
            modeSwitchItem.action = #selector(switchToLyricsAction)
        }

        // Theme checkmarks
        for (theme, item) in themeItems {
            item.state = ThemeManager.shared.currentTheme == theme ? .on : .off
        }

        // Size checkmarks + parent enable
        sizeMenuItem.isEnabled = (currentMode == .aura)
        for (size, item) in sizeItems {
            item.state = AuraSizeManager.shared.currentSize == size ? .on : .off
        }

        // Lock item
        if currentMode == .lyrics {
            lockItem.title = isLyricsLocked ? "Unlock Lyrics View" : "Lock Lyrics View"
            lockItem.action = #selector(toggleLockLyrics)
            lockItem.state = isLyricsLocked ? .on : .off
            lockItem.isEnabled = isWindowVisible
        } else {
            lockItem.title = isAuraLocked ? "Unlock Aura Mode" : "Lock Aura Mode"
            lockItem.action = #selector(toggleLockAura)
            lockItem.state = isAuraLocked ? .on : .off
            lockItem.isEnabled = isWindowVisible
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
        updateMenu()
    }

    @objc private func toggleLockAura() {
        isAuraLocked.toggle()
        windowManager?.setAuraWindowClickThrough(enabled: isAuraLocked)
        updateMenu()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func changeTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? AppTheme else { return }
        ThemeManager.shared.setTheme(theme)
        updateMenu()
    }

    @objc private func changeAuraSize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? AuraSize else { return }
        AuraSizeManager.shared.setSize(size)
        updateMenu()
    }
}
