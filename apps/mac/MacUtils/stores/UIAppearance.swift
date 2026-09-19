import Observation
import SwiftUI

@MainActor
@Observable
final class UIAppearancePreferences {
    static let shared = UIAppearancePreferences()

    var accent: UIAccentColor {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: PreferenceKey.uiAccentColor)
        }
    }

    private init() {
        let storedAccent = UserDefaults.standard.string(forKey: PreferenceKey.uiAccentColor)
        accent = UIAccentColor(rawValue: storedAccent ?? "") ?? .automatic
    }

    var accentColor: Color {
        accent.nsColor.map { Color(nsColor: $0) } ?? .accentColor
    }
}
