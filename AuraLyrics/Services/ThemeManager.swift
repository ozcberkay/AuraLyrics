import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case adaptive = "Adaptive (Album Art)"
    case darkAura = "Dark Aura"
    case minimalist = "Minimalist (Frosted)"
    
    var id: String { self.rawValue }
}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: AppDefaults.Key.appTheme.rawValue)
        }
    }

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: AppDefaults.Key.appTheme.rawValue),
           let theme = AppTheme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .adaptive
        }
    }
    
    func setTheme(_ theme: AppTheme) {
        withAnimation {
            self.currentTheme = theme
        }
    }
}
