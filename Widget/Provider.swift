import WidgetKit
import SwiftUI

struct CostEntry: TimelineEntry {
    let date: Date
    let costData: CostData?
    let error: String?
    let displayAmount: (Double) -> String

    static let placeholder = CostEntry(
        date: Date(),
        costData: CostData(
            totalBalance: 100,
            todayCost: 5,
            monthlyCost: 30,
            dailyCosts: (0..<14).map { i in
                DailyCost(date: "06-\(String(format: "%02d", i + 1))", amount: Double.random(in: 1...10))
            },
            modelCosts: [
                ModelCost(model: "deepseek-v4-pro", amount: 18, percentage: 60, totalTokens: 2_500_000),
                ModelCost(model: "deepseek-v4-flash", amount: 12, percentage: 40, totalTokens: 8_000_000),
            ],
            lastUpdated: Date(),
            todayBaseBalance: 100,
            monthStartBalance: 130
        ),
        error: nil,
        displayAmount: { String(format: "¥%.2f", $0 * 7.25) }
    )
}

struct CostProvider: TimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CostEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CostEntry>) -> Void) {
        let entry = buildEntry()
        // 每小时刷新一次
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

    private func buildEntry() -> CostEntry {
        let costData = AppGroup.loadCostData()
        let error = AppGroup.loadError()
        let settings = AppGroup.loadSettings()

        let displayAmount: (Double) -> String = { amount in
            switch settings.currency {
            case .cny:
                return String(format: "¥%.2f", amount)
            case .usd:
                return String(format: "$%.2f", amount / settings.exchangeRate)
            }
        }

        return CostEntry(
            date: Date(),
            costData: costData,
            error: error,
            displayAmount: displayAmount
        )
    }
}
