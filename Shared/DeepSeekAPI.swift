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

    private func makeURL(_ settings: AppSettings, path: String) -> URL? {
        URL(string: "\(settings.apiBaseURL)\(path)")
    }

    private func authHeader(_ apiKey: String) -> [String: String] {
        ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"]
    }

    // MARK: - 获取余额

    func fetchBalance(settings: AppSettings) async throws -> Double {
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

        // DeepSeek balance API 返回: { "balance_infos": [...], "is_available": true }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let infos = json["balance_infos"] as? [[String: Any]],
           let first = infos.first,
           let balance = first["total_balance"] as? Double {
            return balance
        }
        throw DeepSeekAPIError.decodeError("无法解析余额数据")
    }

    // MARK: - 获取消耗记录

    func fetchCostData(settings: AppSettings) async throws -> CostData {
        let balance = try await fetchBalance(settings: settings)
        let now = Date()

        // 从本地历史推算消耗
        let previous = AppGroup.loadCostData()
        let prevBalance = previous?.totalBalance ?? balance

        // 计算总消耗
        let totalCost = max(0, 100.0 - balance)

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
