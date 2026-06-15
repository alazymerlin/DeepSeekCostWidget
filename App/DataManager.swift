import Foundation
import Combine

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var costData: CostData?
    @Published var isLoading = false
    @Published var lastError: String?

    var updateIconHandler: ((CostData?) -> Void)?

    private var timer: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    private init() {
        costData = AppGroup.loadCostData()
        lastError = AppGroup.loadError()
        loadSettingsAndStartTimer()
    }

    // MARK: - Timer

    private func loadSettingsAndStartTimer() {
        timer?.cancel()
        let settings = AppGroup.loadSettings()
        let interval = TimeInterval(max(settings.refreshIntervalMinutes, 5) * 60)
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
        _ = timer // retain
    }

    func updateRefreshInterval() {
        loadSettingsAndStartTimer()
    }

    // MARK: - Refresh

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            lastError = nil
            AppGroup.clearError()

            let settings = AppGroup.loadSettings()

            guard !settings.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
                lastError = "请先配置 API Key"
                AppGroup.saveError(lastError!)
                isLoading = false
                return
            }

            do {
                let data = try await DeepSeekAPI.shared.fetchCostData(settings: settings)
                costData = data
                AppGroup.saveCostData(data)
            } catch {
                lastError = error.localizedDescription
                AppGroup.saveError(lastError!)
            }

            isLoading = false
            updateIconHandler?(costData)
        }
    }

    // MARK: - Currency conversion

    func displayAmount(_ amount: Double) -> String {
        let settings = AppGroup.loadSettings()
        switch settings.currency {
        case .cny:
            return String(format: "¥%.2f", amount)
        case .usd:
            let usd = amount / settings.exchangeRate
            return String(format: "$%.2f", usd)
        }
    }
}
