import AppKit
import SwiftUI

class WindowManager: NSObject, NSApplicationDelegate {
    var listPanel: FloatingPanel?
    var auraPanel: FloatingPanel?
    
    private var sizeObserver: Any?
    
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
        // Get initial size from AuraSizeManager
        let initialSize = AuraSizeManager.shared.currentSize
        let auraP = FloatingPanel(
            contentRect: NSRect(
                x: 100,
                y: 100,
                width: initialSize.windowWidth,
                height: initialSize.windowHeight
            ),
            backing: .buffered,
            defer: false
        )
        auraP.contentView = NSHostingView(rootView: AuraView())
        // auraP.makeKeyAndOrderFront(nil) // Start hidden
        self.auraPanel = auraP
        
        // --- Observe Aura Size Changes ---
        sizeObserver = NotificationCenter.default.addObserver(
            forName: .auraSizeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let newSize = notification.object as? AuraSize else { return }
            self?.resizeAuraPanel(to: newSize)
        }
        
        // --- Setup Menu Bar ---
        MenuBarManager.shared.setup(windowManager: self)
        
        // Ensure the app doesn't close when all windows are hidden (though this is a panel)
        NSApp.setActivationPolicy(.accessory)
    }
    
    deinit {
        if let observer = sizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Aura Size Management
    
    private func resizeAuraPanel(to size: AuraSize) {
        guard let panel = auraPanel else { return }
        
        // Get current frame to preserve position (centered resize)
        let currentFrame = panel.frame
        let currentCenterX = currentFrame.midX
        let currentCenterY = currentFrame.midY
        
        // Calculate new frame
        let newWidth = size.windowWidth
        let newHeight = size.windowHeight
        let newX = currentCenterX - (newWidth / 2)
        let newY = currentCenterY - (newHeight / 2)
        
        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
        
        // Animate the resize
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }
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

