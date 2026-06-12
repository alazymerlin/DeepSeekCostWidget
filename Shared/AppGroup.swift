import Foundation

enum AppGroup {
    private static let suiteNameKey = "APP_GROUP_SUITE_NAME"
    static let suiteName = "URXRP62983.com.deepseekcostwidget.group"

    static let defaults = UserDefaults(suiteName: suiteName)!

    private static let costDataKey = "com.deepseekcostwidget.costData"
    private static let settingsKey = "com.deepseekcostwidget.settings"
    private static let errorKey = "com.deepseekcostwidget.lastError"

    // MARK: - CostData

    static func saveCostData(_ data: CostData) {
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: costDataKey)
            defaults.synchronize()
        }
    }

    static func loadCostData() -> CostData? {
        guard let data = defaults.data(forKey: costDataKey) else { return nil }
        return try? JSONDecoder().decode(CostData.self, from: data)
    }

    // MARK: - Settings

    static func saveSettings(_ settings: AppSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
            defaults.synchronize()
        }
    }

    static func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    // MARK: - Error

    static func saveError(_ message: String) {
        defaults.set(message, forKey: errorKey)
        defaults.synchronize()
    }

    static func loadError() -> String? {
        defaults.string(forKey: errorKey)
    }

    static func clearError() {
        defaults.removeObject(forKey: errorKey)
        defaults.synchronize()
    }
}
