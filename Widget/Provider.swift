import WidgetKit
import SwiftUI

struct CostEntry: TimelineEntry {
    let date: Date
    let costData: CostData?
    let error: String?
    let displayAmount: (Double) -> String
}

struct CostProvider: TimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        let data = CostData(totalBalance: 100, todayCost: 5, monthlyCost: 30,
            dailyCosts: (0..<14).map { i in DailyCost(date: "06-\(String(format: "%02d",i+1))", amount: Double.random(in: 1...10)) },
            modelCosts: [ModelCost(model: "deepseek-v4-pro", amount: 18, percentage: 60, totalTokens: 0),
                         ModelCost(model: "deepseek-v4-flash", amount: 12, percentage: 40, totalTokens: 0)],
            lastUpdated: Date(), todayBaseBalance: 100, monthStartBalance: 130)
        return CostEntry(date: Date(), costData: data, error: nil, displayAmount: { String(format: "¥%.2f", $0) })
    }

    func getSnapshot(in context: Context, completion: @escaping (CostEntry) -> Void) {
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CostEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func buildEntry() async -> CostEntry {
        let settings = AppGroup.loadSettings()
        let fmt: (Double) -> String = { settings.displayAmount($0) }

        if let cached = AppGroup.loadCostData() {
            return CostEntry(date: Date(), costData: cached, error: nil, displayAmount: fmt)
        }

        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let error = key.isEmpty ? L10n.noAPIKey : (AppGroup.loadError() ?? L10n.openAppToConfig)
        return CostEntry(date: Date(), costData: nil, error: error, displayAmount: fmt)
    }
}
