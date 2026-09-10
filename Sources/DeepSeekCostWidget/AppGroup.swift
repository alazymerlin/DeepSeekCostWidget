import Foundation
import Security

/// 本地存储 — 使用 UserDefaults + Keychain
enum AppGroup {
    static let defaults = UserDefaults.standard

    // MARK: - Keys

    private static let costDataKey = "com.deepseekcostwidget.costData"
    private static let settingsKey = "com.deepseekcostwidget.settings"
    private static let errorKey = "com.deepseekcostwidget.lastError"
    private static let usageDataKey = "com.deepseekcostwidget.usageData"
    private static let csvSnapshotKey = "com.deepseekcostwidget.csvSnapshot"
    private static let apiKeyService = "com.deepseekcostwidget.apiKey"
    private static let apiKeyUserDefaultsKey = "com.deepseekcostwidget.apiKey.ud"
    private static let apiKeyAccount = "DeepSeekAPIKey"

    // MARK: - CSV 快照余额（用于月消耗计算）

    /// CSV 导入时的余额快照: snapshotBalance = balance_at_import + csvTotalCost ≈ 月初余额
    /// monthlyCost = snapshotBalance - currentBalance
    static var csvSnapshotBalance: Double {
        get { defaults.double(forKey: csvSnapshotKey) }
        set { defaults.set(newValue, forKey: csvSnapshotKey) }
    }

    // MARK: - CSV 导入路径

    /// CSV 文件存放路径: ~/.deepseek_cost_widget/
    static var csvDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".deepseek_cost_widget")
    }

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

    // MARK: - UsageData (CSV)

    static func saveUsageData(_ data: ParsedUsageData) {
        if let d = try? JSONEncoder().encode(data) {
            defaults.set(d, forKey: usageDataKey)
        }
    }

    static func loadUsageData() -> ParsedUsageData? {
        guard let d = defaults.data(forKey: usageDataKey),
              let data = try? JSONDecoder().decode(ParsedUsageData.self, from: d) else { return nil }
        // 缓存含旧模型名（如已合并的视觉模型）→ 作废，触发从 CSV 重新解析
        if data.costByModel.keys.contains("deepseek-v4-flash-vision-exp") { return nil }
        return data
    }

    /// 尝试从 ~/.deepseek_cost_widget/ 导入当月 CSV 文件
    /// 优先匹配当月，fallback 到最新文件
    static func tryImportCSV() -> ParsedUsageData? {
        let dir = csvDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return nil
        }

        // 当前月份标识 (yyyyMM)
        let currentMonth = Self.monthKey()

        // 按月份匹配：文件名如 cost-2026-07-01_2026-07-16.csv → 提取 202607
        func monthFrom(filename: String) -> String? {
            // cost-YYYY-MM-DD_YYYY-MM-DD.csv
            let parts = filename.split(separator: "-")
            guard parts.count >= 3, let year = Int(parts[1]), let month = Int(parts[2]) else { return nil }
            return String(format: "%04d%02d", year, month)
        }

        let costFiles = files.filter { $0.lastPathComponent.hasPrefix("cost-") && $0.pathExtension == "csv" }
        let amountFiles = files.filter { $0.lastPathComponent.hasPrefix("amount-") && $0.pathExtension == "csv" }

        // 优先匹配当月，取其中最新（结束日期最大）的文件
        let sortedCost = costFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        let sortedAmount = amountFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        let matchedCost = sortedCost.first { monthFrom(filename: $0.lastPathComponent) == currentMonth }
            ?? sortedCost.first
        let matchedAmount = sortedAmount.first { monthFrom(filename: $0.lastPathComponent) == currentMonth }
            ?? sortedAmount.first

        guard let costFile = matchedCost, let amountFile = matchedAmount,
              let costStr = try? String(contentsOf: costFile, encoding: .utf8),
              let amountStr = try? String(contentsOf: amountFile, encoding: .utf8) else {
            return nil
        }

        let costCSV = costStr.hasPrefix("\u{FEFF}") ? String(costStr.dropFirst()) : costStr
        let amountCSV = amountStr.hasPrefix("\u{FEFF}") ? String(amountStr.dropFirst()) : amountStr

        let parsed = UsageCSV.parse(costCSV: costCSV, amountCSV: amountCSV)
        guard !parsed.records.isEmpty else { return nil }

        saveUsageData(parsed)
        return parsed
    }

    private static func monthKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMM"; return f.string(from: Date())
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

        // 从 Keychain 恢复 API Key
        if let key = loadAPIKey(), !key.isEmpty {
            settings.apiKey = key
        } else if let udKey = defaults.string(forKey: apiKeyUserDefaultsKey), !udKey.isEmpty {
            settings.apiKey = udKey
        }

        return settings
    }

    // MARK: - Error

    static func saveError(_ m: String) { defaults.set(m, forKey: errorKey) }
    static func loadError() -> String? { defaults.string(forKey: errorKey) }
    static func clearError() { defaults.removeObject(forKey: errorKey) }

    // MARK: - API Key (Keychain)

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
