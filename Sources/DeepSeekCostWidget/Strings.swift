import Foundation

/// 根据系统语言自动选择中/英文文案
enum L10n {
    private static var isZh: Bool {
        let lang = Locale.preferredLanguages.first ?? ""
        return lang.hasPrefix("zh")
    }

    // MARK: - Tab & Navigation

    static var overview: String { isZh ? "概览" : "Overview" }
    static var settings: String { isZh ? "设置" : "Settings" }
    static var refresh: String { isZh ? "刷新" : "Refresh" }
    static var openPanel: String { isZh ? "打开面板" : "Open Panel" }
    static var quit: String { isZh ? "退出" : "Quit" }

    // MARK: - Cost labels

    static var monthlyCost: String { isZh ? "本月消耗" : "Monthly" }
    static var totalCost: String { isZh ? "累计消耗" : "Total Spent" }
    static var todayCost: String { isZh ? "今日消耗" : "Today" }
    static var balance: String { isZh ? "余额" : "Balance" }
    static var modelCost: String { isZh ? "模型消耗" : "Model Usage" }
    static var updated: String { isZh ? "更新于" : "Updated" }
    static var estimatedFromBalance: String { isZh ? "根据余额变化估算" : "Estimated from balance changes" }
    static var noModelDetails: String { isZh ? "余额接口暂无模型明细" : "No model breakdown from balance API" }

    // MARK: - Widget labels

    static var trend14Days: String { isZh ? "近14天消耗趋势" : "14-Day Trend" }
    static var modelDistribution: String { isZh ? "模型分布" : "Distribution" }
    static var openAppToConfig: String { isZh ? "打开菜单栏 App 进行设置" : "Open menubar app to configure" }

    // MARK: - States

    static var loading: String { isZh ? "加载中..." : "Loading..." }
    static var noAPIKey: String { isZh ? "请先配置 API Key" : "Please configure API Key" }

    // MARK: - Settings

    static var apiSection: String { isZh ? "DeepSeek API" : "DeepSeek API" }
    static var apiKey: String { isZh ? "API Key" : "API Key" }
    static var apiBaseURL: String { isZh ? "API Base URL" : "API Base URL" }
    static var refreshInterval: String { isZh ? "刷新间隔" : "Refresh Interval" }
    static var displaySection: String { isZh ? "显示" : "Display" }
    static var currencyUnit: String { isZh ? "货币单位" : "Currency" }

    // MARK: - Codex

    static var codexUsage: String { isZh ? "Codex 用量" : "Codex Usage" }
    static var codex5h: String { isZh ? "5小时" : "5-Hour" }
    static var codexWeekly: String { isZh ? "本周" : "Weekly" }
    static var codexCredits: String { isZh ? "额度" : "Credits" }
    static var codexResets: String { isZh ? "后重置" : "reset" }
    static var codexRemaining: String { isZh ? "还剩" : "left" }
    static var codexResetted: String { isZh ? "已重置" : "reset done" }
    static var codexNoPermission: String { isZh ? "无「文稿」文件夹访问权限" : "No access to Documents folder" }
    static var codexPermissionHint: String {
        isZh ? "Codex 数据在 ~/Documents 下，需授权后才能读取"
             : "Codex data lives under ~/Documents; permission required"
    }
    static var openSystemSettings: String { isZh ? "打开系统设置" : "Open Settings" }

    // MARK: - Time intervals

    static func minutes(_ n: Int) -> String {
        isZh ? "\(n)分钟" : "\(n) min"
    }
}
