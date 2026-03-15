import Foundation

/// Consolidated UserDefaults keys for AuraLyrics.
/// All UserDefaults access must use AppDefaults.Key.xxx.rawValue — no inline string literals.
enum AppDefaults {
    enum Key: String {
        case auraSize = "AuraSize"
        case appTheme = "AppTheme"
        case appMode  = "AuraLyricsAppMode"
        case listPanelFrame = "ListPanelFrame"   // UIPX-01: floating lyrics panel frame
        case auraPanelFrame = "AuraPanelFrame"   // UIPX-01: aura panel frame
    }
}
