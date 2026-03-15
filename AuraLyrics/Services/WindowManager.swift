import AppKit
import Combine
import SwiftUI

class WindowManager: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var listPanel: FloatingPanel?
    var auraPanel: FloatingPanel?

    private var cancellables = Set<AnyCancellable>()
    
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
        listP.delegate = self
        restoreFrame(for: listP, key: .listPanelFrame)
        
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
        auraP.delegate = self
        restoreFrame(for: auraP, key: .auraPanelFrame)
        
        // --- Observe Aura Size Changes via Combine ---
        AuraSizeManager.shared.$currentSize
            .dropFirst()  // skip initial emission — auraPanel already sized at creation above
            .receive(on: RunLoop.main)
            .sink { [weak self] newSize in
                self?.resizeAuraPanel(to: newSize)
            }
            .store(in: &cancellables)
        
        // --- Setup Menu Bar ---
        MenuBarManager.shared.setup(windowManager: self)
        
        // Ensure the app doesn't close when all windows are hidden (though this is a panel)
        NSApp.setActivationPolicy(.accessory)
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
    
    // MARK: - Frame Persistence (UIPX-01)

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        if panel === listPanel {
            UserDefaults.standard.set(
                NSStringFromRect(panel.frame),
                forKey: AppDefaults.Key.listPanelFrame.rawValue
            )
        } else if panel === auraPanel {
            UserDefaults.standard.set(
                NSStringFromRect(panel.frame),
                forKey: AppDefaults.Key.auraPanelFrame.rawValue
            )
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        if panel === listPanel {
            UserDefaults.standard.set(
                NSStringFromRect(panel.frame),
                forKey: AppDefaults.Key.listPanelFrame.rawValue
            )
        }
        // auraPanel resize is programmatic (AuraSizeManager) — not persisted here
    }

    private func restoreFrame(for panel: FloatingPanel, key: AppDefaults.Key) {
        guard let saved = UserDefaults.standard.string(forKey: key.rawValue) else { return }
        let frame = NSRectFromString(saved)
        guard frame != .zero,
              let screen = NSScreen.main,
              screen.visibleFrame.intersects(frame) else { return }
        panel.setFrame(frame, display: false)
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

