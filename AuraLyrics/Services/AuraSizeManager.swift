import SwiftUI
import Combine

/// Represents the 5 size presets for Aura Mode.
///
/// All dimensional properties are derived from `scaleFactor` and the medium
/// baseline values, eliminating the repetitive per-case switch statements.
enum AuraSize: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact:    return "\u{1D2C}\u{1D43} Compact"
        case .small:      return "A\u{1D43} Small"
        case .medium:     return "Aa Medium"
        case .large:      return "Aa Large"
        case .extraLarge: return "AA Extra Large"
        }
    }

    /// Scale factor relative to medium (1.0)
    var scaleFactor: CGFloat {
        switch self {
        case .compact:    return 0.6
        case .small:      return 0.8
        case .medium:     return 1.0
        case .large:      return 1.2
        case .extraLarge: return 1.4
        }
    }

    // MARK: - Derived dimensions (base value x scaleFactor)

    /// Window width for Aura panel
    var windowWidth: CGFloat { round(500 * scaleFactor) }

    /// Window height for Aura panel
    var windowHeight: CGFloat { round(134 * scaleFactor) }

    /// Main/active line font size
    var activeFontSize: CGFloat { round(27 * scaleFactor) }

    /// Previous/next line font size
    var inactiveFontSize: CGFloat { round(17 * scaleFactor) }

    /// Minimum height for inactive lines
    var inactiveLineHeight: CGFloat { round(26 * scaleFactor) }

    /// Minimum height for active line
    var activeLineHeight: CGFloat { round(44 * scaleFactor) }

    /// Info mode track title font size
    var trackTitleFontSize: CGFloat { round(21 * scaleFactor) }

    /// Info mode artist font size
    var artistFontSize: CGFloat { round(14 * scaleFactor) }

    /// Error/status message font size
    var statusFontSize: CGFloat { max(6, round(9 * scaleFactor)) }

    /// Waiting message font size
    var waitingFontSize: CGFloat { round(14 * scaleFactor) }
}

// MARK: - AuraSizeManager

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
        if let saved = UserDefaults.standard.string(forKey: sizeKey),
           let size = AuraSize(rawValue: saved) {
            self.currentSize = size
        } else {
            self.currentSize = .medium
        }
    }

    func setSize(_ size: AuraSize) {
        guard size != currentSize else { return }

        // Do NOT wrap in withAnimation — SwiftUI views already declare
        // `.animation(.spring(...), value: currentSize)` so they animate
        // automatically.  The previous withAnimation call raced against the
        // AppKit NSAnimationContext in WindowManager.resizeAuraPanel, which
        // caused crashes on rapid size changes.
        if Thread.isMainThread {
            self.currentSize = size
        } else {
            DispatchQueue.main.async { self.currentSize = size }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let auraSizeDidChange = Notification.Name("auraSizeDidChange")
}
