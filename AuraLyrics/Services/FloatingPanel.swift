import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    /// - Parameter drawsShadow: A borderless panel derives its shadow from the *alpha silhouette*
    ///   of its content, not from its frame. That is what you want for the lyrics panel, which is
    ///   an opaque rounded card. For a panel whose content is transparent text, macOS traces a
    ///   dark contour around every glyph and around any blurred glow behind them — so Aura mode
    ///   passes `false`.
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool, drawsShadow: Bool = true) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: backing,
            defer: flag
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.backgroundColor = .clear
        self.isMovableByWindowBackground = true
        self.hasShadow = drawsShadow
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    func setClickThrough(_ enabled: Bool) {
        self.ignoresMouseEvents = enabled
        // Lock state communicated via menu bar checkmark — no visual alpha change needed (UIPX-02)
    }
}
