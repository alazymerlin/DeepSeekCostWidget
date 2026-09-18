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
                // 刷新 —— 从底栏挪上来并放大；加载中原地换成转圈
                if dm.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 28, height: 28)
                } else {
                    Button(action: { dm.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .help(L10n.refresh)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Content area
            if tab == 0 { mainView }
            else { settingsView }

            Divider()

            // Bottom bar —— 只剩两个 tab：刷新已上移，退出已改到右键菜单
            HStack(spacing: 20) {
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
                    // 余额 — 决定"还能不能用"，放最顶
                    balanceCard(data)

                    // 今日消耗 — 总额并入标题行，下面按模型拆
                    // CSV 覆盖今日时用当日明细，否则按本月占比估算
                    modelCard(
                        icon: "sun.max.fill", color: .orange,
                        title: "今日消耗",
                        total: dm.displayAmount(data.todayCost),
                        models: data.modelCosts,
                        note: dm.todayHasCSVDetail ? nil : "CSV 未含今日，按本月占比估算"
                    )

                    // 本月消耗
                    modelCard(
                        icon: "calendar.badge.clock", color: .blue,
                        title: "本月消耗",
                        total: dm.displayAmount(data.monthlyCost),
                        models: dm.monthlyModelCosts,
                        note: dm.csvDataThroughLabel.isEmpty
                            ? nil
                            : "CSV 截至 \(dm.csvDataThroughLabel)，其后按占比估算"
                    )

                    // Codex 额度用量 — 读本地会话文件，无需任何配置。
                    // 放最后：它与 DeepSeek 是两套独立的额度体系，不该插在"总额→明细"中间
                    codexSection
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

    private func balanceCard(_ data: CostData) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wallet.bifold.fill")
                .font(.caption).foregroundColor(.green)
            Text("余额").font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(dm.displayAmount(data.totalBalance))
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundColor(.accentColor)
            Text("\(L10n.updated) \(formatTime(data.lastUpdated))")
                .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                .padding(.leading, 2)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Codex 用量

    @ViewBuilder
    private var codexSection: some View {
        switch dm.codexStatus {
        case .ok(let usage):
            codexCard(usage)
        case .permissionDenied:
            codexPermissionCard
        case .noCodexDir, .notFound:
            // 没装 Codex / 还没产生用量 —— 不占位
            EmptyView()
        }
    }

    private func codexCard(_ usage: CodexUsage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.caption2).foregroundColor(.purple)
                Text(L10n.codexUsage).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(L10n.updated) \(formatTime(usage.recordedAt))")
                    .font(.caption2).foregroundColor(.secondary.opacity(0.5))
            }

            // 额度 —— 与 DeepSeek 余额同款大字，一眼看还剩多少
            if let credits = usage.creditsBalance {
                HStack(spacing: 4) {
                    Text(L10n.codexCredits).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f", credits))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
            }

            if let primary = usage.primary { codexRow(primary) }
            if let secondary = usage.secondary { codexRow(secondary) }

        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func codexRow(_ window: CodexWindow) -> some View {
        let used = window.effectivePercent(now: dm.now)
        let remaining = max(0, 100 - used)
        // 配色仍按已用量判断紧张度：剩得越少越红，与"条越短"方向一致
        let color = codexColor(used)

        return HStack(spacing: 6) {
            Text(window.isWeekly ? L10n.codexWeekly : L10n.codex5h)
                .font(.caption).foregroundColor(.secondary)
                .frame(width: 38, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: max(2, geo.size.width * remaining / 100))
                }
            }
            .frame(height: 5)

            Text("\(L10n.codexRemaining) \(String(format: "%.0f%%", remaining))")
                .font(.caption.monospacedDigit()).foregroundColor(color)
                .frame(width: 62, alignment: .trailing)

            Text(codexResetLabel(window))
                .font(.caption2).foregroundColor(.secondary.opacity(0.6))
                .frame(width: 72, alignment: .trailing)
        }
    }

    /// 用量配色：<50% 绿、50–80% 橙、>80% 红
    private func codexColor(_ percent: Double) -> Color {
        if percent >= 80 { return .red }
        if percent >= 50 { return .orange }
        return .green
    }

    /// 已过重置点则显示「已重置」，否则显示重置时刻（周窗口给日期）
    private func codexResetLabel(_ window: CodexWindow) -> String {
        guard dm.now < window.resetsAt else { return L10n.codexResetted }
        let f = DateFormatter()
        f.dateFormat = window.isWeekly ? "M/d" : "HH:mm"
        return "\(f.string(from: window.resetsAt)) \(L10n.codexResets)"
    }

    private var codexPermissionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundColor(.orange)
                Text(L10n.codexNoPermission).font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Text(L10n.codexPermissionHint)
                .font(.caption2).foregroundColor(.secondary.opacity(0.6))
            Button(action: openFilesAndFoldersSettings) {
                Label(L10n.openSystemSettings, systemImage: "gear")
                    .font(.caption2)
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openFilesAndFoldersSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Settings tab

    @StateObject private var settingsStore = SettingsStore()
    @State private var keyTest: KeyTestState = .idle

    /// API Key 连通性测试的三态
    enum KeyTestState: Equatable {
        case idle, testing
        case ok(Double)
        case failed(String)
    }

    /// 只露前 3 位和后 4 位，够认出是哪个 key，又不至于泄露
    private var maskedKey: String {
        let k = settingsStore.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard k.count > 8 else { return String(repeating: "•", count: max(k.count, 4)) }
        return "\(k.prefix(3))••••\(k.suffix(4))"
    }

    @ViewBuilder
    private var keyTestButton: some View {
        switch keyTest {
        case .idle:
            Button("测试") { testConnection() }
                .buttonStyle(.bordered).controlSize(.small)
        case .testing:
            ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
        case .ok(let balance):
            Label(String(format: "连接正常 · 余额 %.2f", balance), systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundColor(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption2).foregroundColor(.orange)
                .lineLimit(2)
        }
    }

    private func testConnection() {
        keyTest = .testing
        Task {
            do {
                let balance = try await DeepSeekAPI.shared.validateKey(settings: AppGroup.loadSettings())
                keyTest = .ok(balance)
            } catch {
                keyTest = .failed(error.localizedDescription)
            }
        }
    }

    private var settingsView: some View {
        Group {
            VStack(spacing: 12) {
                // ── API 配置 ──
                settingsCard(title: "API 配置", icon: "key.fill", color: .blue) {
                    settingField(label: "API Key") {
                        SecureField("sk-...", text: $settingsStore.apiKey)
                            .textFieldStyle(.roundedBorder).font(.caption)
                        if !settingsStore.apiKey.isEmpty {
                            HStack(spacing: 6) {
                                Text("已保存 \(maskedKey)")
                                    .font(.caption2).foregroundColor(.secondary.opacity(0.6))
                                Spacer()
                                keyTestButton
                            }
                        }
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
                            Text("已用 \(dm.csvMonthLabel) 月 CSV 校准")
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
                        // 「期间累计」是 CSV 样本期内的合计，与概览页按月推算的
                        // 「本月消耗」口径不同，必须写清楚，否则两个数字看着像互相矛盾
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text").font(.caption2).foregroundColor(.secondary)
                            Text("样本期 \(dm.csvDateRange)·累计 ¥\(String(format: "%.2f", dm.csvTotalCost))·\(dm.csvImportDateLabel)导入")
                                .font(.caption2).foregroundColor(.secondary.opacity(0.7))
                            Spacer()
                        }
                    }
                    Label("占比样本越久越可能偏离，建议每月重导；重导后当日可显示真实 token",
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(10)
        }
        .onChange(of: settingsStore.apiKey) {
            settingsStore.save()
            keyTest = .idle   // 改了 key，先前的测试结果就不作数了
        }
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

    /// 总额 + 模型拆分卡 —— 总额并入标题行，省掉一张重复的卡
    private func modelCard(
        icon: String, color: Color, title: String,
        total: String, models: [ModelCost], note: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // 标题行：左标签、右总额（与下面各行金额右对齐到同一列）
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(total)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
            // 列头 —— 两张卡都保留同样的列，金额列才能上下对齐
            HStack(spacing: 4) {
                Spacer()
                Text("Token").font(.caption2).foregroundColor(.secondary.opacity(0.4))
                    .frame(width: 44, alignment: .trailing)
                Text("费用").font(.caption2).foregroundColor(.secondary.opacity(0.4))
                    .frame(width: 58, alignment: .trailing)
            }
            ForEach(models) { ModelCostRow(mc: $0, dm: dm) }
            if let note {
                Text(note)
                    .font(.caption2).foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                .frame(width: 46, alignment: .leading)

            // 占比条 —— 与 Codex 卡同一套写法
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(Color.accentColor)
                        .frame(width: min(geo.size.width,
                                         max(2, geo.size.width * mc.percentage / 100)))
                }
            }
            .frame(height: 5)

            Text(String(format: "%.0f%%", mc.percentage))
                .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)

            // token 明细只有 CSV 覆盖到的日期才有，否则显示 —
            Text(mc.totalTokens > 0 ? mc.formattedTokens : "—")
                .font(.caption2.monospacedDigit()).foregroundColor(.secondary.opacity(0.6))
                .frame(width: 44, alignment: .trailing)

            Text(dm.displayAmount(mc.amount))
                .font(.caption.monospacedDigit())
                .foregroundColor(.accentColor)
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}
