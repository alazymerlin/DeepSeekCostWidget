import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var apiKey: String
    @Published var refreshInterval: Int
    @Published var currency: AppSettings.Currency
    @Published var apiBaseURL: String

    init() {
        let s = AppGroup.loadSettings()
        apiKey = s.apiKey
        refreshInterval = s.refreshIntervalMinutes
        currency = s.currency
        apiBaseURL = s.apiBaseURL
    }

    func save() {
        let existing = AppGroup.loadSettings()
        let s = AppSettings(
            apiKey: apiKey,
            refreshIntervalMinutes: refreshInterval,
            currency: currency,
            exchangeRate: existing.exchangeRate,
            apiBaseURL: apiBaseURL,
            initialBalance: existing.initialBalance,
            lastTrackedMonth: existing.lastTrackedMonth,
            todayBaseBalance: existing.todayBaseBalance,
            todayBaseDate: existing.todayBaseDate
        )
        AppGroup.saveSettings(s)
        DataManager.shared.updateRefreshInterval()
    }
}
