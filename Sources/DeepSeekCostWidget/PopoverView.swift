import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PopoverView: View {
    @ObservedObject private var dm = DataManager.shared
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header — 随 tab 动态变化
            HStack {
                Label(tab == 0 ? L10n.overview : L10n.settings,
                      systemImage: tab == 0 ? "chart.bar.fill" : "gearshape.fill")
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
        // 自适应高度：测量内容实际高度并调整窗口
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: PopoverHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(PopoverHeightKey.self) { height in
            guard height > 0 else { return }
            NotificationCenter.default.post(
                name: NSNotification.Name("ResizePopover"),
                object: NSSize(width: 320, height: height)
            )
        }
    }

    private func switchTab(to newTab: Int) {
        tab = newTab
    }

    // MARK: - Main tab

    @ViewBuilder
    private var mainView: some View {
        if let data = dm.costData {
            Group {
                VStack(spacing: 8) {
                    // 本月消耗 + 今日消耗 — 双卡片，大字蓝色
                    HStack(spacing: 8) {
                        cardView(
                            icon: "calendar.badge.clock",
                            color: .blue,
                            title: "本月消耗",
                            amount: dm.displayAmount(data.monthlyCost)
                        )
                        cardView(
                            icon: "sun.max.fill",
                            color: .orange,
                            title: "今日消耗",
                            amount: dm.displayAmount(data.todayCost)
                        )
                    }

                    // 模型统计 — 始终显示
                    modelCard(
                        icon: "sun.max.fill", color: .orange,
                        title: "当日模型消耗",
                        models: data.modelCosts.isEmpty
                            ? defaultModelCosts(todayAmount: data.todayCost)
                            : data.modelCosts
                    )
                    modelCard(
                        icon: "calendar.badge.clock", color: .blue,
                        title: "当月模型消耗",
                        models: dm.monthlyModelCosts.isEmpty
                            ? defaultModelCosts(todayAmount: data.monthlyCost)
                            : dm.monthlyModelCosts
                    )

                    // 余额卡片 — 底部小字
                    HStack {
                        Image(systemName: "wallet.bifold.fill")
                            .font(.caption).foregroundColor(.green)
                        Text("余额").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(dm.displayAmount(data.totalBalance))
                            .font(.subheadline.monospacedDigit().weight(.medium))
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 底部状态
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("\(dm.csvCalibrationLabel) · \(formatTime(data.lastUpdated))")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(10)
            }
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

    private func cardView(icon: String, color: Color, title: String, amount: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
            Text(amount)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Settings tab

    @StateObject private var settingsStore = SettingsStore()

    private var settingsView: some View {
        Group {
            VStack(spacing: 12) {
                // ── API 配置 ──
                settingsCard(title: "API 配置", icon: "key.fill", color: .blue) {
                    settingField(label: "API Key") {
                        SecureField("sk-...", text: $settingsStore.apiKey)
                            .textFieldStyle(.roundedBorder).font(.caption)
                    }
                    settingField(label: "API URL") {
                        TextField("https://api.deepseek.com", text: $settingsStore.apiBaseURL)
                            .textFieldStyle(.roundedBorder).font(.caption)
                    }
                    settingRow(label: "刷新间隔") {
                        Picker("", selection: $settingsStore.refreshInterval) {
                            Text("5m").tag(5); Text("15m").tag(15)
                            Text("30m").tag(30); Text("60m").tag(60)
                        }
                        .pickerStyle(.segmented).font(.caption2)
                    }
                    settingRow(label: "货币") {
                        Picker("", selection: $settingsStore.currency) {
                            Text("CNY").tag(AppSettings.Currency.cny)
                            Text("USD").tag(AppSettings.Currency.usd)
                        }
                        .pickerStyle(.segmented).font(.caption2)
                        .frame(width: 120)
                    }
                }

                // ── 用量校准 ──
                settingsCard(title: "用量校准", icon: "chart.bar.doc.horizontal", color: .green) {
                    HStack(spacing: 6) {
                        if dm.hasCSVData {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption).foregroundColor(.green)
                            Text("已校准 \(dm.ratioSource)")
                                .font(.caption).foregroundColor(.secondary)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundColor(.orange)
                            Text("未校准").font(.caption).foregroundColor(.orange)
                        }
                        Spacer()
                        Button(action: { importCSVFile() }) {
                            Label("导入", systemImage: "square.and.arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered).controlSize(.small).tint(.green)
                    }
                    if dm.hasCSVData {
                        HStack {
                            Image(systemName: "doc.text").font(.caption2).foregroundColor(.secondary)
                            Text("\(dm.csvCalibrationLabel) · 数据 \(dm.csvDateRange) · 累计 ¥\(String(format: "%.0f", dm.csvTotalCost))")
                                .font(.caption2).foregroundColor(.secondary.opacity(0.7))
                            Spacer()
                        }
                    }
                    Label("校准后全自动追踪，无需每月更新", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(12)
        }
        .onChange(of: settingsStore.apiKey) { settingsStore.save() }
        .onChange(of: settingsStore.refreshInterval) { settingsStore.save() }
        .onChange(of: settingsStore.currency) { settingsStore.save() }
        .onChange(of: settingsStore.apiBaseURL) { settingsStore.save() }
    }

    // MARK: - Settings helpers

    private func settingsCard<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption).foregroundColor(color)
                Text(title).font(.caption.weight(.semibold)).foregroundColor(.secondary)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func settingField<Content: View>(
        label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            content()
        }
    }

    private func settingRow<Content: View>(
        label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
                .frame(width: 58, alignment: .leading)
            Spacer()
            content()
        }
    }

    // MARK: - Model Card

    private func modelCard(icon: String, color: Color, title: String, models: [ModelCost]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("费用").font(.caption2).foregroundColor(.secondary.opacity(0.5)).frame(width: 70, alignment: .trailing)
                Text("Token").font(.caption2).foregroundColor(.secondary.opacity(0.5)).frame(width: 60, alignment: .trailing)
            }
            ForEach(models) { ModelCostRow(mc: $0, dm: dm) }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func defaultModelCosts(todayAmount: Double) -> [ModelCost] {
        let models = ["deepseek-v4-pro", "deepseek-v4-flash"]
        let each = todayAmount / Double(models.count)
        return models.map { ModelCost(model: $0, amount: each, percentage: 100.0 / Double(models.count), totalTokens: 0) }
    }

    // MARK: - Helpers

    // MARK: - CSV Import

    private func importCSVFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 DeepSeek 导出的 CSV 文件"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        // 分类 cost 和 amount 文件
        let costURL = panel.urls.first { $0.lastPathComponent.hasPrefix("cost-") }
        let amountURL = panel.urls.first { $0.lastPathComponent.hasPrefix("amount-") }

        guard let cost = costURL ?? panel.urls.first,
              let amount = amountURL ?? panel.urls.first else { return }

        // 复制到 ~/.deepseek_cost_widget/
        let dir = AppGroup.csvDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destCost = dir.appendingPathComponent(cost.lastPathComponent)
        let destAmount = dir.appendingPathComponent(amount.lastPathComponent)
        try? FileManager.default.removeItem(at: destCost)
        try? FileManager.default.removeItem(at: destAmount)
        try? FileManager.default.copyItem(at: cost, to: destCost)
        try? FileManager.default.copyItem(at: amount, to: destAmount)

        // 触发重新导入和刷新
        if dm.reimportCSV() {
            dm.refresh()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }


}

// MARK: - Popover 自适应高度

private struct PopoverHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Model cost row

private struct ModelCostRow: View {
    let mc: ModelCost; let dm: DataManager

    var body: some View {
        HStack(spacing: 4) {
            Text(mc.displayName)
                .font(.caption).fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(dm.displayAmount(mc.amount))
                .font(.caption.monospacedDigit())
                .frame(width: 70, alignment: .trailing)
                .foregroundColor(.accentColor)
            Text(mc.formattedTokens)
                .font(.caption2).foregroundColor(.secondary.opacity(0.6))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}
