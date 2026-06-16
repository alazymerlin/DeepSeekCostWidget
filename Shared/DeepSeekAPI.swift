import Foundation

enum DeepSeekAPIError: LocalizedError {
    case invalidURL, invalidResponse, httpError(Int, String), decodeError(String), noData
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 API 地址"
        case .invalidResponse: return "无效的响应"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodeError(let d): return "数据解析失败: \(d)"
        case .noData: return "暂无消耗数据"
        }
    }
}

final class DeepSeekAPI {
    static let shared = DeepSeekAPI()
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        return URLSession(configuration: c)
    }()

    func fetchCostData(settings: AppSettings) async throws -> CostData {
        let now = Date()
        let cal = Calendar.current
        var prev = AppGroup.loadCostData() ?? CostData.empty
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            throw DeepSeekAPIError.decodeError("请先配置 API Key")
        }

        // 1. 获取余额
        let baseURL = settings.apiBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/user/balance") else {
            throw DeepSeekAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await session.data(for: req)
        guard let r = resp as? HTTPURLResponse else { throw DeepSeekAPIError.invalidResponse }
        guard r.statusCode == 200 else {
            throw DeepSeekAPIError.httpError(r.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let balanceResponse: BalanceResponse
        do {
            balanceResponse = try JSONDecoder().decode(BalanceResponse.self, from: data)
        } catch {
            throw DeepSeekAPIError.decodeError(error.localizedDescription)
        }

        guard let balanceInfo = balanceResponse.balance_infos.first(where: { $0.currency == "CNY" })
                ?? balanceResponse.balance_infos.first else {
            throw DeepSeekAPIError.decodeError("无法解析余额")
        }
        let balance = Self.d(balanceInfo.total_balance)

        // 2. 判断是否是新的天/月
        let newDay = !cal.isDate(prev.lastUpdated, inSameDayAs: now)
        let newMonth = !cal.isDate(prev.lastUpdated, equalTo: now, toGranularity: .month)
        let monthKey = Self.monthFmt.string(from: now)
        let dayKey = Self.dayFmt.string(from: now)
        let configuredMonthBase = settings.lastTrackedMonth == monthKey && settings.initialBalance > 0
            ? settings.initialBalance
            : balance

        // 3. 识别充值：余额增加 → 基准同步上调，保留已记录的消耗
        let delta = balance - prev.totalBalance

        if settings.todayBaseDate == dayKey,
           let todayBase = settings.todayBaseBalance,
           todayBase > 0 {
            prev.todayBaseBalance = todayBase
        } else if newDay || prev.todayBaseBalance == 0 {
                prev.todayBaseBalance = balance
        } else if delta > 0 {
            prev.todayBaseBalance += delta
        }
        let todayCost = max(0, prev.todayBaseBalance - balance)

        if newMonth || prev.monthStartBalance == 0 ||
            (settings.lastTrackedMonth == monthKey &&
             settings.initialBalance > 0 &&
             prev.monthStartBalance != settings.initialBalance) {
            prev.monthStartBalance = configuredMonthBase
        } else if delta > 0 {
            prev.monthStartBalance += delta
        }
        let monthlyCost = max(0, prev.monthStartBalance - balance)

        // 5. 每日记录 — 始终维护最近14天窗口，以今天为最后一天
        var costsByDate = Dictionary(uniqueKeysWithValues: prev.dailyCosts.map { ($0.date, $0.amount) })
        let todayStr = Self.fmt.string(from: now)
        costsByDate[todayStr] = todayCost
        let dailyCosts = (0..<14).reversed().compactMap { offset -> DailyCost? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let dateString = Self.fmt.string(from: date)
            return DailyCost(date: dateString, amount: costsByDate[dateString] ?? 0)
        }

        // 基于今日消耗(todayCost)和百分比计算各模型的日消耗金额 — 不用月数据
        let modelCosts: [ModelCost] = {
            guard let manual = settings.manualModelCosts, !manual.isEmpty else { return [] }
            let totalPct = manual.reduce(0) { $0 + $1.percentage }
            guard totalPct > 0 else { return manual }
            return manual.map { mc in
                ModelCost(model: mc.model, amount: todayCost * mc.percentage / totalPct, percentage: mc.percentage, totalTokens: mc.totalTokens)
            }
        }()

        return CostData(
            totalBalance: balance,
            todayCost: todayCost,
            monthlyCost: monthlyCost,
            dailyCosts: dailyCosts,
            modelCosts: modelCosts,
            lastUpdated: now,
            todayBaseBalance: prev.todayBaseBalance,
            monthStartBalance: prev.monthStartBalance
        )
    }

    private static func d(_ v: Any?) -> Double {
        guard let v else { return 0 }
        if let n = v as? Double { return n }
        if let s = v as? String, let n = Double(s) { return n }
        return 0
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM-dd"; return f
    }()

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f
    }()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private struct BalanceResponse: Decodable {
        let balance_infos: [BalanceInfo]
    }

    private struct BalanceInfo: Decodable {
        let currency: String
        let total_balance: String
    }
}
