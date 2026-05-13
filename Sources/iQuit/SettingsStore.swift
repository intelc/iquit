import Foundation
import iQuitCore

enum SettingsStore {
    private static let key = "com.iquit.settings.v1"
    private static let onboardingCompletedKey = "com.iquit.onboardingCompleted.v1"

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return AppSettings()
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return AppSettings()
        }
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompletedKey)
    }

    static func setOnboardingCompleted(_ isCompleted: Bool) {
        UserDefaults.standard.set(isCompleted, forKey: onboardingCompletedKey)
    }
}
