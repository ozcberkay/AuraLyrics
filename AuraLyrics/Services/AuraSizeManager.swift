import SwiftUI
import Combine

/// Represents the 5 size presets for Aura Mode
enum AuraSize: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    
    var id: String { self.rawValue }
    
    /// Display name with visual indicator
    var displayName: String {
        switch self {
        case .compact: return "ᴬᵃ Compact"
        case .small: return "Aᵃ Small"
        case .medium: return "Aa Medium"
        case .large: return "Aa Large"
        case .extraLarge: return "AA Extra Large"
        }
    }
    
    /// Scale factor relative to medium (1.0)
    var scaleFactor: CGFloat {
        switch self {
        case .compact: return 0.6
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.4
        }
    }
    
    /// Window width for Aura panel
    var windowWidth: CGFloat {
        switch self {
        case .compact: return 360
        case .small: return 450
        case .medium: return 500
        case .large: return 600
        case .extraLarge: return 720
        }
    }
    
    /// Window height for Aura panel
    var windowHeight: CGFloat {
        switch self {
        case .compact: return 96
        case .small: return 120
        case .medium: return 134
        case .large: return 160
        case .extraLarge: return 192
        }
    }
    
    /// Main/active line font size
    var activeFontSize: CGFloat {
        switch self {
        case .compact: return 19
        case .small: return 24
        case .medium: return 27
        case .large: return 32
        case .extraLarge: return 38
        }
    }
    
    /// Previous/next line font size
    var inactiveFontSize: CGFloat {
        switch self {
        case .compact: return 12
        case .small: return 15
        case .medium: return 17
        case .large: return 20
        case .extraLarge: return 24
        }
    }
    
    /// Minimum height for inactive lines
    var inactiveLineHeight: CGFloat {
        switch self {
        case .compact: return 18
        case .small: return 22
        case .medium: return 26
        case .large: return 30
        case .extraLarge: return 36
        }
    }
    
    /// Minimum height for active line
    var activeLineHeight: CGFloat {
        switch self {
        case .compact: return 30
        case .small: return 38
        case .medium: return 44
        case .large: return 50
        case .extraLarge: return 60
        }
    }
    
    /// Info mode track title font size
    var trackTitleFontSize: CGFloat {
        switch self {
        case .compact: return 14
        case .small: return 18
        case .medium: return 21
        case .large: return 24
        case .extraLarge: return 29
        }
    }
    
    /// Info mode artist font size
    var artistFontSize: CGFloat {
        switch self {
        case .compact: return 10
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 19
        }
    }
    
    /// Error/status message font size
    var statusFontSize: CGFloat {
        switch self {
        case .compact: return 6
        case .small: return 8
        case .medium: return 9
        case .large: return 10
        case .extraLarge: return 12
        }
    }
    
    /// Waiting message font size
    var waitingFontSize: CGFloat {
        switch self {
        case .compact: return 10
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 19
        }
    }
}

class AuraSizeManager: ObservableObject {
    static let shared = AuraSizeManager()
    
    private let sizeKey = "AuraSize"
    
    @Published var currentSize: AuraSize {
        didSet {
            UserDefaults.standard.set(currentSize.rawValue, forKey: sizeKey)
            NotificationCenter.default.post(name: .auraSizeDidChange, object: currentSize)
        }
    }
    
    private init() {
        if let savedSize = UserDefaults.standard.string(forKey: sizeKey),
           let size = AuraSize(rawValue: savedSize) {
            self.currentSize = size
        } else {
            // Default to Medium (Kademe 3)
            self.currentSize = .medium
        }
    }
    
    func setSize(_ size: AuraSize) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.currentSize = size
        }
    }
}

// Notification for size changes
extension Notification.Name {
    static let auraSizeDidChange = Notification.Name("auraSizeDidChange")
}
