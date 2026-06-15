import SwiftUI

struct PopoverView: View {
    @ObservedObject private var dm = DataManager.shared
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(L10n.overview, systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .opacity(dm.isLoading ? 1 : 0)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Content area
            if tab == 0 { mainView }
            else { settingsView }

            Divider()

            // Bottom bar
            HStack(spacing: 8) {
                Button(action: { dm.refresh() }) {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentColor)

                Spacer()

                Button(action: { switchTab(to: 0) }) {
                    Label(L10n.overview, systemImage: "chart.bar")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(tab == 0 ? .accentColor : .secondary)

                Button(action: { switchTab(to: 1) }) {
                    Label(L10n.settings, systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(tab == 1 ? .accentColor : .secondary)

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Label(L10n.quit, systemImage: "power")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    private func switchTab(to newTab: Int) {
        tab = newTab
        let size: NSSize = newTab == 0
            ? NSSize(width: 320, height: 400)
            : NSSize(width: 320, height: 460)
        NotificationCenter.default.post(
            name: NSNotification.Name("ResizePopover"),
            object: size
        )
    }

    // MARK: - Main tab

    @ViewBuilder
    private var mainView: some View {
        if let data = dm.costData {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    costBlock(title: L10n.monthlyCost, amount: dm.displayAmount(data.monthlyCost))
                    costBlock(title: L10n.todayCost, amount: dm.displayAmount(data.todayCost))
                }
                HStack {
                    Text("💰 余额").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text(dm.displayAmount(data.totalBalance)).font(.subheadline.monospacedDigit())
                }
                if !data.modelCosts.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.modelCost).font(.caption).foregroundColor(.secondary)
                        ForEach(data.modelCosts) { ModelCostRow(mc: $0, dm: dm) }
                    }
                }
                Text(L10n.updated + "  \(formatTime(data.lastUpdated))")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(12)
        } else if let error = dm.lastError {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundColor(.orange)
                Text(error).font(.caption).multilineTextAlignment(.center).foregroundColor(.secondary)
            }.padding(20)
        } else {
            VStack(spacing: 8) {
                ProgressView().scaleEffect(0.6)
                Text(L10n.loading).font(.caption).foregroundColor(.secondary)
            }.frame(minHeight: 200).padding(20)
        }
    }

    // MARK: - Settings tab

    @StateObject private var settingsStore = SettingsStore()

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(L10n.apiSection) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.apiKey).font(.caption2).foregroundColor(.secondary)
                    SecureField("sk-...", text: $settingsStore.apiKey)
                        .textFieldStyle(.roundedBorder).font(.caption)
                    Text(L10n.apiBaseURL).font(.caption2).foregroundColor(.secondary)
                    TextField("https://api.deepseek.com", text: $settingsStore.apiBaseURL)
                        .textFieldStyle(.roundedBorder).font(.caption)
                    HStack {
                        Text(L10n.refreshInterval).font(.caption2).foregroundColor(.secondary)
                        Picker("", selection: $settingsStore.refreshInterval) {
                            Text(L10n.minutes(5)).tag(5); Text(L10n.minutes(15)).tag(15)
                            Text(L10n.minutes(30)).tag(30); Text(L10n.minutes(60)).tag(60)
                        }.pickerStyle(.segmented).font(.caption2)
                    }
                }.padding(8)
            }
            GroupBox("显示") {
                HStack {
                    Text(L10n.currencyUnit).font(.caption2).foregroundColor(.secondary)
                    Picker("", selection: $settingsStore.currency) {
                        Text("CNY ¥").tag(AppSettings.Currency.cny)
                        Text("USD $").tag(AppSettings.Currency.usd)
                    }.pickerStyle(.segmented).font(.caption2)
                }.padding(8)
            }
        }
        .padding(12)
        .onChange(of: settingsStore.apiKey) { settingsStore.save() }
        .onChange(of: settingsStore.refreshInterval) { settingsStore.save() }
        .onChange(of: settingsStore.currency) { settingsStore.save() }
        .onChange(of: settingsStore.apiBaseURL) { settingsStore.save() }
        
    }

    // MARK: - Helpers

    private func costBlock(title: String, amount: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(amount).font(.title3.monospacedDigit()).fontWeight(.semibold).foregroundColor(.accentColor)
        }
    }
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

// MARK: - Model cost row

private struct ModelCostRow: View {
    let mc: ModelCost; let dm: DataManager
    @State private var hovered = false
    private var barPercent: Double { min(mc.amount * 10, 100) }

    var body: some View {
        HStack(spacing: 6) {
            Text(mc.displayName).font(.caption).frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(hovered ? 0.8 : 0.5))
                        .frame(width: geo.size.width * barPercent / 100)
                }.frame(height: 8)
                .onHover { h in hovered = h }
            Text(dm.displayAmount(mc.amount)).font(.caption.monospacedDigit()).frame(width: 70, alignment: .trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
