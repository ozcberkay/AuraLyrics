import AppKit
import SwiftUI

class WindowManager: NSObject, NSApplicationDelegate {
    var listPanel: FloatingPanel?
    var auraPanel: FloatingPanel?

    private var sizeObserver: Any?
    private var isResizing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // --- Lyrics View Panel ---
        let listP = FloatingPanel(
            contentRect: NSRect(x: 100, y: 300, width: 400, height: 600),
            backing: .buffered,
            defer: false
        )
        listP.contentView = NSHostingView(rootView: LyricsView())
        self.listPanel = listP

        // --- Aura Mode Panel ---
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

        // --- Menu Bar ---
        MenuBarManager.shared.setup(windowManager: self)

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

        // If a resize animation is already running, cancel it immediately
        // by snapping to the final frame so we start the new animation from
        // a clean state.  This prevents stacking animations that fight each
        // other and cause crashes.
        if isResizing {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            panel.animator().setFrame(panel.frame, display: false)
            NSAnimationContext.endGrouping()
        }

        isResizing = true

        let currentFrame = panel.frame
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY

        let newWidth = size.windowWidth
        let newHeight = size.windowHeight
        var newX = centerX - newWidth / 2
        var newY = centerY - newHeight / 2

        // Clamp to visible screen bounds so the panel doesn't go off-screen
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            newX = min(max(newX, visible.minX), visible.maxX - newWidth)
            newY = min(max(newY, visible.minY), visible.maxY - newHeight)
        }

        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(newFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isResizing = false
        })
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
