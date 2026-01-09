import SwiftUI

@main
struct AuraLyricsApp: App {
    // Connect the AppDelegate
    @NSApplicationDelegateAdaptor(WindowManager.self) var appDelegate
    
    var body: some Scene {
        // We don't use a standard WindowGroup for the main UI since we use floating panels custom-managed by WindowManager.
        // However, we can keep a hidden one or standard one if we want a "Main" window.
        // For menu-bar only apps or custom window apps, we often use Settings or minimal scene.
        Settings {
            EmptyView()
        }
    }
}
