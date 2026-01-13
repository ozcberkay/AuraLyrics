import AppKit
import Combine
import SwiftUI

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
    private let modeKey = "AuraLyricsAppMode"
    
    // State to track locks (independent of mode)
    private var isLyricsLocked = false
    private var isAuraLocked = false
    
    // Track visibility
    private var isWindowVisible = true
    
    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // Load saved mode
        if let savedModeString = UserDefaults.standard.string(forKey: modeKey),
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
        updateMenu()
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
    
    private func updateMenu() {
        let menu = NSMenu()
        
        // --- Controls ---
        let controlsItem = NSMenuItem()
        let controlsView = MenuControlsView()
        let hostingView = NSHostingView(rootView: controlsView)
        // Adjust frame to match the new vertical layout size (Artwork 120 + Text + Controls + Padding)
        hostingView.frame = NSRect(x: 0, y: 0, width: 260, height: 290)
        controlsItem.view = hostingView
        menu.addItem(controlsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- View Controls ---
        
        // 1. Show/Hide Current
        if !isWindowVisible {
            let title = currentMode == .lyrics ? "Show Lyrics View" : "Show Aura Mode"
            let item = NSMenuItem(title: title, action: #selector(showCurrentWindowAction), keyEquivalent: "s")
            item.target = self
            menu.addItem(item)
        } else {
            let title = "Hide Window"
            let item = NSMenuItem(title: title, action: #selector(hideWindowsAction), keyEquivalent: "h")
            item.target = self
            menu.addItem(item)
        }
        
        // 2. Switch Mode
        // Context-aware switching
        if currentMode == .lyrics {
            let item = NSMenuItem(title: "Switch to Aura Mode", action: #selector(switchToAuraAction), keyEquivalent: "l")
            item.target = self
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "Return to Lyrics View", action: #selector(switchToLyricsAction), keyEquivalent: "l")
            item.target = self
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Theme ---
        let themeMenu = NSMenu()
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)
        
        for theme in AppTheme.allCases {
            let item = NSMenuItem(title: theme.rawValue, action: #selector(changeTheme(_:)), keyEquivalent: "")
            item.target = self
            // Note: Cannot easily bind state here without observing, but we can check current
            item.state = (ThemeManager.shared.currentTheme == theme) ? .on : .off
            item.representedObject = theme
            themeMenu.addItem(item)
        }
        
        // --- Aura Size ---
        let sizeMenu = NSMenu()
        let sizeItem = NSMenuItem(title: "Aura Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        // Only enable when in Aura mode
        sizeItem.isEnabled = (currentMode == .aura)
        menu.addItem(sizeItem)
        
        for size in AuraSize.allCases {
            let item = NSMenuItem(title: size.displayName, action: #selector(changeAuraSize(_:)), keyEquivalent: "")
            item.target = self
            item.state = (AuraSizeManager.shared.currentSize == size) ? .on : .off
            item.representedObject = size
            sizeMenu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())

        
        // --- Locking ---
        // Dynamically show lock based on active mode
        if currentMode == .lyrics {
             // Lock Lyrics
            let title = isLyricsLocked ? "Unlock Lyrics View" : "Lock Lyrics View"
            let lockItem = NSMenuItem(title: title, action: #selector(toggleLockLyrics), keyEquivalent: "")
            lockItem.state = isLyricsLocked ? .on : .off
            lockItem.target = self
            lockItem.isEnabled = isWindowVisible
            menu.addItem(lockItem)
        } else {
             // Lock Aura
            let title = isAuraLocked ? "Unlock Aura Mode" : "Lock Aura Mode"
             let lockItem = NSMenuItem(title: title, action: #selector(toggleLockAura), keyEquivalent: "")
            lockItem.state = isAuraLocked ? .on : .off
            lockItem.target = self
            lockItem.isEnabled = isWindowVisible
            menu.addItem(lockItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        

        
        // --- Quit ---
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
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
