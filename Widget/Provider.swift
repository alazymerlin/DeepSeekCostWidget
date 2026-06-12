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
            totalCost: 50,
            todayCost: 5,
            monthlyCost: 30,
            dailyCosts: (0..<14).map { i in
                DailyCost(date: "06-\(String(format: "%02d", i + 1))", amount: Double.random(in: 1...10))
            },
            modelCosts: [
                ModelCost(model: "deepseek-chat", amount: 30, percentage: 60),
                ModelCost(model: "deepseek-coder", amount: 15, percentage: 30),
                ModelCost(model: "deepseek-reasoner", amount: 5, percentage: 10),
            ],
            lastUpdated: Date()
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

        let displayAmount: (Double) -> String = { usd in
            switch settings.currency {
            case .cny:
                return String(format: "¥%.2f", usd * settings.exchangeRate)
            case .usd:
                return String(format: "$%.2f", usd)
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
