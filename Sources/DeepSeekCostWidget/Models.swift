import Foundation

struct CostData: Codable, Equatable {
    var totalBalance: Double
    var todayCost: Double
    var monthlyCost: Double
    var dailyCosts: [DailyCost]
    var modelCosts: [ModelCost]
    var lastUpdated: Date
    var todayBaseBalance: Double
    var monthStartBalance: Double

    static let empty = CostData(
        totalBalance: 0,
        todayCost: 0,
        monthlyCost: 0,
        dailyCosts: [],
        modelCosts: [],
        lastUpdated: .distantPast,
        todayBaseBalance: 0,
        monthStartBalance: 0
    )
}

struct DailyCost: Codable, Identifiable, Equatable {
    var id: String { date }
    let date: String
    let amount: Double
}

struct ModelCost: Codable, Identifiable, Equatable {
    var id: String { model }
    let model: String
    let amount: Double
    let percentage: Double
    let totalTokens: Int64

    /// 模型显示名
    /// 现役只有两个模型；历史名（v4-flash / vision-exp）在 UsageCSV.normalizeModel
    /// 里已归并到 deepseek-flash，不会走到这张表
    static let knownModels: [String: String] = [
        "deepseek-flash": "Flash",
        "deepseek-v4-pro": "V4 Pro",
    ]

    var displayName: String {
        Self.knownModels[model] ?? model
    }

    var formattedTokens: String {
        if totalTokens >= 1_000_000_000 {
            return String(format: "%.1fB", Double(totalTokens) / 1_000_000_000)
        } else if totalTokens >= 1_000_000 {
            return String(format: "%.1fM", Double(totalTokens) / 1_000_000)
        } else if totalTokens >= 1_000 {
            return String(format: "%.1fK", Double(totalTokens) / 1_000)
        }
        return "\(totalTokens)"
    }
}

// MARK: - Codex 用量

/// Codex 的一个额度窗口（5 小时 / 周）
struct CodexWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date

    /// 周窗口（10080 分钟）；否则按 5 小时窗口处理
    var isWeekly: Bool { windowMinutes >= 10080 }

    /// 有效用量 —— 已过重置点说明额度已归还，
    /// 且该记录之后没有任何新数据，故为 0
    func effectivePercent(now: Date) -> Double {
        now >= resetsAt ? 0 : usedPercent
    }
}

/// 从本地 Codex 会话文件中读到的限流快照
struct CodexUsage: Equatable, Sendable {
    let primary: CodexWindow?
    let secondary: CodexWindow?
    let creditsBalance: Double?
    /// 快照时间（取源文件修改时间）
    let recordedAt: Date
    let sourceFile: String
}

struct AppSettings: Codable {
    var apiKey: String = ""
    var refreshIntervalMinutes: Int = 15
    var currency: Currency = .cny
    var exchangeRate: Double = 7.25
    var apiBaseURL: String = "https://api.deepseek.com"
    var initialBalance: Double = 0
    var lastTrackedMonth: String = ""
    var todayBaseBalance: Double?
    var todayBaseDate: String?

    enum Currency: String, Codable, CaseIterable {
        case usd = "USD"
        case cny = "CNY"
    }

    func displayAmount(_ amount: Double) -> String {
        switch currency {
        case .cny:
            return String(format: "¥%.2f", amount)
        case .usd:
            let rate = exchangeRate > 0 ? exchangeRate : 7.25
            return String(format: "$%.2f", amount / rate)
        }
    }
}
