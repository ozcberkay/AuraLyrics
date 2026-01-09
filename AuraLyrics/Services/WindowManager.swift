import AppKit
import SwiftUI

class WindowManager: NSObject, NSApplicationDelegate {
    var listPanel: FloatingPanel?
    var karaokePanel: FloatingPanel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // --- Setup List Window ---
        let listP = FloatingPanel(
            contentRect: NSRect(x: 100, y: 300, width: 400, height: 600),
            backing: .buffered,
            defer: false
        )
        listP.contentView = NSHostingView(rootView: LyricsView())
        listP.makeKeyAndOrderFront(nil)
        self.listPanel = listP
        
        // --- Setup Karaoke Window ---
        // Hidden by default
        let karaokeP = FloatingPanel(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 160),
            backing: .buffered,
            defer: false
        )
        karaokeP.contentView = NSHostingView(rootView: KaraokeView())
        // karaokeP.makeKeyAndOrderFront(nil) // Start hidden
        self.karaokePanel = karaokeP
        
        // --- Setup Menu Bar ---
        MenuBarManager.shared.setup(windowManager: self)
        
        // Ensure the app doesn't close when all windows are hidden (though this is a panel)
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - Window Control
    
    func toggleListWindow(visible: Bool) {
        if visible {
            listPanel?.makeKeyAndOrderFront(nil)
        } else {
            listPanel?.orderOut(nil)
        }
    }
    
    func toggleKaraokeWindow(visible: Bool) {
        if visible {
            karaokePanel?.makeKeyAndOrderFront(nil)
        } else {
            karaokePanel?.orderOut(nil)
        }
    }
    
    func setListWindowClickThrough(enabled: Bool) {
        listPanel?.setClickThrough(enabled)
    }
    
    func setKaraokeWindowClickThrough(enabled: Bool) {
        karaokePanel?.setClickThrough(enabled)
    }
}
