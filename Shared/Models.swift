import Foundation

struct CostData: Codable, Equatable {
    var totalBalance: Double
    var totalCost: Double
    var todayCost: Double
    var monthlyCost: Double
    var dailyCosts: [DailyCost]
    var modelCosts: [ModelCost]
    var lastUpdated: Date

    static let empty = CostData(
        totalBalance: 0,
        totalCost: 0,
        todayCost: 0,
        monthlyCost: 0,
        dailyCosts: [],
        modelCosts: [],
        lastUpdated: .distantPast
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

    static let knownModels: [String: String] = [
        "deepseek-chat": "Chat",
        "deepseek-coder": "Coder",
        "deepseek-reasoner": "Reasoner"
    ]

    var displayName: String {
        Self.knownModels[model] ?? model
    }
}

struct AppSettings: Codable {
    var apiKey: String = ""
    var refreshIntervalMinutes: Int = 15
    var currency: Currency = .cny
    var exchangeRate: Double = 7.25
    var apiBaseURL: String = "https://api.deepseek.com"

    enum Currency: String, Codable, CaseIterable {
        case usd = "USD"
        case cny = "CNY"
    }
}
