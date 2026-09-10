import Foundation
import Combine

@MainActor
final class DataManager: ObservableObject {
    static let shared = DataManager()

    @Published var costData: CostData?
    @Published var usageData: ParsedUsageData?
    @Published var isLoading = false
    @Published var lastError: String?

    var updateIconHandler: ((CostData?) -> Void)?

    private var timer: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    private init() {
        costData = AppGroup.loadCostData()
        usageData = AppGroup.loadUsageData()
        lastError = AppGroup.loadError()
        loadSettingsAndStartTimer()

        // 尝试自动导入 CSV
        if let imported = AppGroup.tryImportCSV() {
            usageData = imported
        }
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

    // MARK: - CSV

    /// 重新导入 CSV（手动调用）
    func reimportCSV() -> Bool {
        guard let imported = AppGroup.tryImportCSV() else { return false }
        usageData = imported
        // 重置快照，下次刷新时用新CSV + 当前余额重新推算月初基准
        AppGroup.csvSnapshotBalance = 0
        return true
    }

    var hasCSVData: Bool {
        guard let u = usageData else { return false }
        return !u.records.isEmpty
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
                let data = try await DeepSeekAPI.shared.fetchCostData(settings: settings, usageData: usageData)
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
        AppGroup.loadSettings().displayAmount(amount)
    }

    // MARK: - Display helpers

    /// CSV 本月累计费用
    var csvTotalCost: Double {
        usageData?.totalCost ?? 0
    }

    /// CSV 日期范围
    var csvDateRange: String {
        guard let u = usageData, !u.csvStartDate.isEmpty else { return "" }
        return "\(fmtCSV(u.csvStartDate))~\(fmtCSV(u.csvEndDate))"
    }

    /// 当前月份标识
    var currentMonthLabel: String {
        let f = DateFormatter(); f.dateFormat = "M月"; return f.string(from: Date())
    }

    /// 模型占比来源说明
    var ratioSource: String {
        if hasCSVData, let u = usageData {
            let m = u.csvEndDate.dropFirst(4).prefix(2)
            return "\(m)月CSV校准"
        }
        return "默认"
    }

    /// 校准日期说明，如 "8月21日校准"
    var csvCalibrationLabel: String {
        guard hasCSVData, let u = usageData else { return "未校准" }
        let f = DateFormatter(); f.dateFormat = "M月d日"
        return "\(f.string(from: u.lastImportDate))校准"
    }

    /// 今日是否在 CSV 覆盖范围内（有当日模型明细）
    /// 否 → 无法拆分当日模型消耗，不能按历史占比猜（会显示错误的模型）
    var todayHasCSVDetail: Bool {
        guard let u = usageData else { return false }
        return u.dailyCostsByModel[Self.dayKey()] != nil
    }

    /// CSV 数据截止到几号，如 "9/8"
    var csvDataThroughLabel: String {
        guard let u = usageData, u.csvEndDate.count == 8 else { return "" }
        return "\(u.csvEndDate.dropFirst(4).prefix(2))/\(u.csvEndDate.suffix(2))"
    }

    private static func dayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: Date())
    }

    /// 当月模型消耗 — 按 CSV 当月累计精确拆分（与"本月消耗"卡片口径一致）
    var monthlyModelCosts: [ModelCost] {
        guard let costData else { return [] }
        return DeepSeekAPI.splitModelCosts(amount: costData.monthlyCost, usageData: usageData)
    }

    private func fmtCSV(_ d: String) -> String {
        guard d.count == 8 else { return d }
        return "\(d.dropFirst(4).prefix(2))/\(d.suffix(2))"
    }
}
