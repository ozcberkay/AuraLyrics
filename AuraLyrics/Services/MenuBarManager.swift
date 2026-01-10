import AppKit
import Combine
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem!
    private weak var windowManager: WindowManager?
    
    // State to track toggles
    private var isListWindowVisible = true
    private var isKaraokeWindowVisible = false
    private var isListLocked = false
    private var isKaraokeLocked = false
    
    func setup(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "LyricsMaster")
        }
        
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
        
        // --- Song Info (Disabled - moved to Karaoke Header) ---
        // let songInfo = "LyricsMaster" 
        // let infoItem = NSMenuItem(title: songInfo, action: nil, keyEquivalent: "")
        // infoItem.isEnabled = false
        // menu.addItem(infoItem)
        
        // menu.addItem(NSMenuItem.separator())
        
        // --- Windows ---
        let toggleList = NSMenuItem(title: "Show List Window", action: #selector(toggleList), keyEquivalent: "l")
        toggleList.state = isListWindowVisible ? .on : .off
        toggleList.target = self
        menu.addItem(toggleList)

        let toggleKaraoke = NSMenuItem(title: "Show Karaoke Window", action: #selector(toggleKaraoke), keyEquivalent: "k")
        toggleKaraoke.state = isKaraokeWindowVisible ? .on : .off
        toggleKaraoke.target = self
        menu.addItem(toggleKaraoke)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Locking ---
        let lockList = NSMenuItem(title: "Lock List (Click-Through)", action: #selector(toggleLockList), keyEquivalent: "")
        lockList.state = isListLocked ? .on : .off
        lockList.target = self
        menu.addItem(lockList)
        
        let lockKaraoke = NSMenuItem(title: "Lock Karaoke (Click-Through)", action: #selector(toggleLockKaraoke), keyEquivalent: "")
        lockKaraoke.state = isKaraokeLocked ? .on : .off
        lockKaraoke.target = self
        menu.addItem(lockKaraoke)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- Quit ---
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Actions
    
    @objc func toggleList() {
        isListWindowVisible.toggle()
        windowManager?.toggleListWindow(visible: isListWindowVisible)
        updateMenu()
    }
    
    @objc func toggleKaraoke() {
        isKaraokeWindowVisible.toggle()
        windowManager?.toggleKaraokeWindow(visible: isKaraokeWindowVisible)
        updateMenu()
    }
    
    @objc private func toggleLockList() {
        isListLocked.toggle()
        windowManager?.setListWindowClickThrough(enabled: isListLocked)
        updateMenu()
    }
    
    @objc private func toggleLockKaraoke() {
        isKaraokeLocked.toggle()
        windowManager?.setKaraokeWindowClickThrough(enabled: isKaraokeLocked)
        updateMenu()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
