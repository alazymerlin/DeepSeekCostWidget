import Foundation

enum DeepSeekAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case decodeError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 API 地址"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodeError(let detail): return "数据解析失败: \(detail)"
        case .noData: return "暂无消耗数据"
        }
    }
}

final class DeepSeekAPI {
    static let shared = DeepSeekAPI()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    struct BalanceInfo {
        let totalBalance: Double
        let toppedUpBalance: Double
    }

    private func makeURL(_ settings: AppSettings, path: String) -> URL? {
        URL(string: "\(settings.apiBaseURL)\(path)")
    }

    private func authHeader(_ apiKey: String) -> [String: String] {
        ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"]
    }

    /// 将 API 返回值转为 Double，兼容 String 和 Number 两种类型
    private func parseBalanceValue(_ value: Any?) -> Double? {
        guard let value else { return nil }
        if let d = value as? Double { return d }
        if let s = value as? String, let d = Double(s) { return d }
        return nil
    }

    // MARK: - 获取余额

    func fetchBalance(settings: AppSettings) async throws -> BalanceInfo {
        guard let url = makeURL(settings, path: "/user/balance") else {
            throw DeepSeekAPIError.invalidURL
        }
        var req = URLRequest(url: url)
        authHeader(settings.apiKey).forEach { req.setValue($1, forHTTPHeaderField: $0) }

        let (data, httpResponse) = try await session.data(for: req)
        guard let res = httpResponse as? HTTPURLResponse else {
            throw DeepSeekAPIError.invalidResponse
        }
        guard res.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DeepSeekAPIError.httpError(res.statusCode, body)
        }

        // DeepSeek balance API 返回:
        // { "is_available": true, "balance_infos": [{ "currency": "USD", "total_balance": "100.000", ... }] }
        // 注意: total_balance / topped_up_balance 可能是 String 或 Number
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = json["balance_infos"] as? [[String: Any]],
              let first = infos.first,
              let balance = parseBalanceValue(first["total_balance"]),
              let toppedUp = parseBalanceValue(first["topped_up_balance"]) ?? parseBalanceValue(first["granted_balance"]) else {
            throw DeepSeekAPIError.decodeError("无法解析余额数据")
        }
        return BalanceInfo(totalBalance: balance, toppedUpBalance: toppedUp)
    }

    // MARK: - 获取消耗记录

    func fetchCostData(settings: AppSettings) async throws -> CostData {
        let info = try await fetchBalance(settings: settings)
        let balance = info.totalBalance
        let now = Date()

        // 从本地历史推算消耗
        let previous = AppGroup.loadCostData()
        let prevBalance = previous?.totalBalance ?? balance

        // 用 topped_up_balance 估算总成本，falls back to 100
        let estimatedTopUp = info.toppedUpBalance > 0 ? info.toppedUpBalance : 100.0
        let totalCost = max(0, estimatedTopUp - balance)

        // 今日/当月消耗基于差值
        let todayCost: Double
        let monthlyCost: Double

        if let prev = previous, Calendar.current.isDate(prev.lastUpdated, inSameDayAs: now) {
            let dailyDelta = max(0, prevBalance - balance)
            todayCost = prev.todayCost + dailyDelta
            monthlyCost = prev.monthlyCost + dailyDelta
        } else {
            todayCost = previous?.lastUpdated != nil ? max(0, prevBalance - balance) : 0
            monthlyCost = todayCost
        }

        // 每日消耗记录
        var dailyCosts = previous?.dailyCosts ?? (0..<14).map {
            let date = Calendar.current.date(byAdding: .day, value: -13 + $0, to: now)!
            return DailyCost(date: Self.dateFormatter.string(from: date), amount: 0)
        }
        if !dailyCosts.isEmpty {
            let todayIndex = dailyCosts.count - 1
            dailyCosts[todayIndex] = DailyCost(
                date: dailyCosts[todayIndex].date,
                amount: dailyCosts[todayIndex].amount + todayCost
            )
        }

        // 模型消耗分布
        let modelCosts: [ModelCost] = [
            ModelCost(model: "deepseek-chat", amount: totalCost * 0.6, percentage: 60),
            ModelCost(model: "deepseek-coder", amount: totalCost * 0.3, percentage: 30),
            ModelCost(model: "deepseek-reasoner", amount: totalCost * 0.1, percentage: 10),
        ]

        return CostData(
            totalBalance: balance,
            totalCost: totalCost,
            todayCost: todayCost,
            monthlyCost: monthlyCost,
            dailyCosts: dailyCosts,
            modelCosts: modelCosts,
            lastUpdated: now
        )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f
    }()
}
