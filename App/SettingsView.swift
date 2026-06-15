import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var apiKey: String
    @Published var refreshInterval: Int
    @Published var currency: AppSettings.Currency
    @Published var apiBaseURL: String
    @Published var initialBalance: Double

    init() {
        let s = AppGroup.loadSettings()
        apiKey = s.apiKey
        refreshInterval = s.refreshIntervalMinutes
        currency = s.currency
        apiBaseURL = s.apiBaseURL
        initialBalance = s.initialBalance
    }

    func save() {
        let s = AppSettings(
            apiKey: apiKey,
            refreshIntervalMinutes: refreshInterval,
            currency: currency,
            exchangeRate: 7.25,
            apiBaseURL: apiBaseURL,
            initialBalance: initialBalance,
            lastTrackedMonth: AppGroup.loadSettings().lastTrackedMonth
        )
        AppGroup.saveSettings(s)
        DataManager.shared.updateRefreshInterval()
    }
}

struct SettingsView: View {
    @StateObject private var store = SettingsStore()

    var body: some View {
        TabView {
            apiTab.tabItem { Label("API", systemImage: "key.fill") }
            generalTab.tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 400, height: 300)
        .onChange(of: store.apiKey) { store.save() }
        .onChange(of: store.refreshInterval) { store.save() }
        .onChange(of: store.currency) { store.save() }
        .onChange(of: store.apiBaseURL) { store.save() }
        .onChange(of: store.initialBalance) { store.save() }
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

    private var generalTab: some View {
        Form {
            Section("显示") {
                Picker("货币单位", selection: $store.currency) {
                    ForEach(AppSettings.Currency.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
            }

            Section("计费基准") {
                HStack {
                    Text("充值总额 (¥)")
                    TextField("0.00", value: $store.initialBalance, format: .number)
                        .frame(width: 80)
                }
                Text("填首次充值金额后，消耗 = 充值总额 - 当前余额")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
