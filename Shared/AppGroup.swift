import Foundation

/// 共享存储 — 使用 App Groups UserDefaults
enum AppGroup {
    static let suiteName = "NG6Z746LU7.com.deepseekcostwidget.group"
    static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    private static let costDataKey = "com.deepseekcostwidget.costData"
    private static let settingsKey = "com.deepseekcostwidget.settings"
    private static let errorKey = "com.deepseekcostwidget.lastError"

    // MARK: - CostData

    static func saveCostData(_ data: CostData) {
        if let d = try? JSONEncoder().encode(data) {
            defaults.set(d, forKey: costDataKey)
        }
    }

    static func loadCostData() -> CostData? {
        guard let d = defaults.data(forKey: costDataKey) else { return nil }
        return try? JSONDecoder().decode(CostData.self, from: d)
    }

    // MARK: - Settings

    static func saveSettings(_ s: AppSettings) {
        if let d = try? JSONEncoder().encode(s) {
            defaults.set(d, forKey: settingsKey)
        }
    }

    static func loadSettings() -> AppSettings {
        guard let d = defaults.data(forKey: settingsKey) else { return AppSettings() }
        return (try? JSONDecoder().decode(AppSettings.self, from: d)) ?? AppSettings()
    }

    // MARK: - Error

    static func saveError(_ m: String) { defaults.set(m, forKey: errorKey) }
    static func loadError() -> String? { defaults.string(forKey: errorKey) }
    static func clearError() { defaults.removeObject(forKey: errorKey) }
}
