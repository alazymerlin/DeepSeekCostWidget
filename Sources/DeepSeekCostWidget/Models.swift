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

    /// 模型显示名（含历史别名）
    static let knownModels: [String: String] = [
        "deepseek-v4-pro": "V4 Pro",
        "deepseek-v4-flash": "V4 Flash",
        "deepseek-flash": "V4.1 Flash",
        "deepseek-v4.1-flash": "V4.1 Flash",
        "deepseek-v4.1-pro": "V4.1 Pro",
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
