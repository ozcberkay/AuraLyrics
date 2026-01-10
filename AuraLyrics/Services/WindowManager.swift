import AppKit
import SwiftUI

class WindowManager: NSObject, NSApplicationDelegate {
    var listPanel: FloatingPanel?
    var auraPanel: FloatingPanel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // --- Setup List Window (Lyrics View) ---
        let listP = FloatingPanel(
            contentRect: NSRect(x: 100, y: 300, width: 400, height: 600),
            backing: .buffered,
            defer: false
        )
        listP.contentView = NSHostingView(rootView: LyricsView())
        // listP.makeKeyAndOrderFront(nil) // Handled by MenuBarManager
        self.listPanel = listP
        
        // --- Setup Aura Window ---
        // Hidden by default
        let auraP = FloatingPanel(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 160),
            backing: .buffered,
            defer: false
        )
        auraP.contentView = NSHostingView(rootView: AuraView())
        // auraP.makeKeyAndOrderFront(nil) // Start hidden
        self.auraPanel = auraP
        
        // --- Setup Menu Bar ---
        MenuBarManager.shared.setup(windowManager: self)
        
        // Ensure the app doesn't close when all windows are hidden (though this is a panel)
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - Window Control
    
    func toggleLyricsWindow(visible: Bool) {
        if visible {
            listPanel?.makeKeyAndOrderFront(nil)
        } else {
            listPanel?.orderOut(nil)
        }
    }
    
    func toggleAuraWindow(visible: Bool) {
        if visible {
            auraPanel?.makeKeyAndOrderFront(nil)
        } else {
            auraPanel?.orderOut(nil)
        }
    }
    
    func setLyricsWindowClickThrough(enabled: Bool) {
        listPanel?.setClickThrough(enabled)
    }
    
    func setAuraWindowClickThrough(enabled: Bool) {
        auraPanel?.setClickThrough(enabled)
    }
}
