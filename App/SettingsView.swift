import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var apiKey: String
    @Published var refreshInterval: Int
    @Published var currency: AppSettings.Currency
    @Published var exchangeRate: Double
    @Published var apiBaseURL: String

    init() {
        let s = AppGroup.loadSettings()
        apiKey = s.apiKey
        refreshInterval = s.refreshIntervalMinutes
        currency = s.currency
        exchangeRate = s.exchangeRate
        apiBaseURL = s.apiBaseURL
    }

    func save() {
        let s = AppSettings(
            apiKey: apiKey,
            refreshIntervalMinutes: refreshInterval,
            currency: currency,
            exchangeRate: exchangeRate,
            apiBaseURL: apiBaseURL
        )
        AppGroup.saveSettings(s)
        DataManager.shared.updateRefreshInterval()
    }
}

struct SettingsView: View {
    @StateObject private var store = SettingsStore()
    @State private var launchAtLogin: Bool = false

    var body: some View {
        TabView {
            generalTab.tabItem { Label("通用", systemImage: "gearshape") }
            apiTab.tabItem { Label("API", systemImage: "key.fill") }
        }
        .frame(width: 400, height: 300)
        .onChange(of: store.apiKey) { store.save() }
        .onChange(of: store.refreshInterval) { store.save() }
        .onChange(of: store.currency) { store.save() }
        .onChange(of: store.exchangeRate) { store.save() }
        .onChange(of: store.apiBaseURL) { store.save() }
    }

    private var generalTab: some View {
        Form {
            Section("显示") {
                Picker("货币单位", selection: $store.currency) {
                    ForEach(AppSettings.Currency.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }

                if store.currency == .cny {
                    HStack {
                        Text("汇率 (1 USD = )")
                        TextField("7.25", value: $store.exchangeRate, format: .number)
                            .frame(width: 80)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var apiTab: some View {
        Form {
            Section("DeepSeek API") {
                SecureField("API Key", text: $store.apiKey)
                    .textContentType(.password)

                HStack {
                    Text("刷新间隔")
                    Picker("", selection: $store.refreshInterval) {
                        Text("5 分钟").tag(5)
                        Text("15 分钟").tag(15)
                        Text("30 分钟").tag(30)
                        Text("1 小时").tag(60)
                    }
                }

                TextField("API Base URL", text: $store.apiBaseURL)
            }
        }
        .formStyle(.grouped)
    }
}
