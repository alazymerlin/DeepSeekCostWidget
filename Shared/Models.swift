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

    static let knownModels: [String: String] = [
        "deepseek-v4-flash": "V4 Flash",
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
    var manualModelCosts: [ModelCost]?

    static let currentUsageMonth = "2026-06"
    static let currentUsageDay = "2026-06-16"
    static let currentBalance = 554.89
    static let currentMonthlyCost = 218.34
    static let currentTodayCost = 3.18

    static var currentMonthStartBalance: Double {
        currentBalance + currentMonthlyCost
    }

    static var currentTodayBaseBalance: Double {
        currentBalance + currentTodayCost
    }

    static let currentManualModelCosts: [ModelCost] = [
        ModelCost(model: "deepseek-v4-flash", amount: 0.16, percentage: 5.05, totalTokens: 0),
        ModelCost(model: "deepseek-v4-pro", amount: 3.01, percentage: 94.95, totalTokens: 0),
    ]

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
