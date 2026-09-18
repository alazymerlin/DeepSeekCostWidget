import Foundation

/// 本地存储 — 全部使用 UserDefaults
enum AppGroup {
    static let defaults = UserDefaults.standard

    // MARK: - Keys

    private static let costDataKey = "com.deepseekcostwidget.costData"
    private static let settingsKey = "com.deepseekcostwidget.settings"
    private static let errorKey = "com.deepseekcostwidget.lastError"
    private static let usageDataKey = "com.deepseekcostwidget.usageData"
    private static let csvSnapshotKey = "com.deepseekcostwidget.csvSnapshot"
    private static let apiKeyUserDefaultsKey = "com.deepseekcostwidget.apiKey.ud"

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
        // 缓存含已归并的历史模型名 → 作废，触发从 CSV 重新解析
        // （模型名归并规则变更后，旧缓存不会自动更新，必须在这里拦一道）
        let mergedLegacyModels: Set<String> = ["deepseek-v4-flash", "deepseek-v4-flash-vision-exp"]
        if !mergedLegacyModels.isDisjoint(with: data.costByModel.keys) { return nil }
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

    /// 不使用 Keychain：本 App 是 adhoc 签名、没有稳定代码身份，钥匙串每次都
    /// 会重新索要密码（重新构建后更甚）；而明文副本本来就在 UserDefaults 里，
    /// 钥匙串并未提供额外保护，只会带来反复弹窗。
    static func saveSettings(_ s: AppSettings) {
        defaults.set(s.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: apiKeyUserDefaultsKey)

        var safeSettings = s
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

        if let key = defaults.string(forKey: apiKeyUserDefaultsKey), !key.isEmpty {
            settings.apiKey = key
        }

        return settings
    }

    // MARK: - Error

    static func saveError(_ m: String) { defaults.set(m, forKey: errorKey) }
    static func loadError() -> String? { defaults.string(forKey: errorKey) }
    static func clearError() { defaults.removeObject(forKey: errorKey) }

}
