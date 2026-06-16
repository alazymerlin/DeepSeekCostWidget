import Foundation
import Security

/// 共享存储 — 使用 App Groups UserDefaults
enum AppGroup {
    static let suiteName = "NG6Z746LU7.com.deepseekcostwidget.group"
    static let defaults = UserDefaults(suiteName: suiteName) ?? .standard

    private static let costDataKey = "com.deepseekcostwidget.costData"
    private static let settingsKey = "com.deepseekcostwidget.settings"
    private static let errorKey = "com.deepseekcostwidget.lastError"
    private static let apiKeyService = "com.deepseekcostwidget.apiKey"
    private static let apiKeyUserDefaultsKey = "com.deepseekcostwidget.apiKey.ud"

    private static let apiKeyAccount = "DeepSeekAPIKey"

    // MARK: - CostData

    static func saveCostData(_ data: CostData) {
        if let d = try? JSONEncoder().encode(data) {
            defaults.set(d, forKey: costDataKey)
        }
    }

    static func loadCostData() -> CostData? {
        guard let d = defaults.data(forKey: costDataKey) else { return nil }
        guard var data = try? JSONDecoder().decode(CostData.self, from: d) else { return nil }
        data.modelCosts = data.modelCosts.filter { mc in
            mc.model != "deepseek-chat-reasoner" &&
            !(mc.totalTokens == 0 &&
              ((mc.model == "deepseek-v4-pro" && mc.percentage == 92) ||
               (mc.model == "deepseek-v4-flash" && mc.percentage == 8)))
        }
        return data
    }

    // MARK: - Settings

    static func saveSettings(_ s: AppSettings) {
        defaults.set(s.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyUserDefaultsKey)

        var safeSettings = s
        saveAPIKey(s.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        safeSettings.apiKey = ""

        if let d = try? JSONEncoder().encode(safeSettings) {
            defaults.set(d, forKey: settingsKey)
        }
    }

    static func loadSettings() -> AppSettings {
        var settings: AppSettings
        if let d = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: d) {
            settings = decoded
        } else {
            settings = AppSettings()
        }

        if let key = loadAPIKey(), !key.isEmpty {
            settings.apiKey = key
        } else if let udKey = defaults.string(forKey: apiKeyUserDefaultsKey), !udKey.isEmpty {
            settings.apiKey = udKey
        } else if !settings.apiKey.isEmpty {
            let legacyKey = settings.apiKey
            settings.apiKey = legacyKey
            saveSettings(settings)
        }

        if settings.initialBalance == 0 {
            settings.initialBalance = AppSettings.currentMonthStartBalance
        }
        if settings.lastTrackedMonth.isEmpty {
            settings.lastTrackedMonth = AppSettings.currentUsageMonth
        }
        if settings.todayBaseBalance == nil {
            settings.todayBaseBalance = AppSettings.currentTodayBaseBalance
        }
        if settings.todayBaseDate == nil {
            settings.todayBaseDate = AppSettings.currentUsageDay
        }
        if settings.manualModelCosts == nil ||
            settings.manualModelCosts?.contains(where: { $0.model == "deepseek-chat-reasoner" }) == true {
            settings.manualModelCosts = AppSettings.currentManualModelCosts
        }

        return settings
    }

    // MARK: - Error

    static func saveError(_ m: String) { defaults.set(m, forKey: errorKey) }
    static func loadError() -> String? { defaults.string(forKey: errorKey) }
    static func clearError() { defaults.removeObject(forKey: errorKey) }

    // MARK: - API Key

    private static func saveAPIKey(_ key: String) {
        if key.isEmpty {
            deleteAPIKey()
            return
        }

        let data = Data(key.utf8)
        let query = apiKeyQuery()
        let attrs: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func loadAPIKey() -> String? {
        var query = apiKeyQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        return key
    }

    private static func deleteAPIKey() {
        SecItemDelete(apiKeyQuery() as CFDictionary)
    }

    private static func apiKeyQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: apiKeyService,
            kSecAttrAccount as String: apiKeyAccount,
        ]
    }
}
