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

    func fetchCostData(settings: AppSettings, usageData: ParsedUsageData? = nil) async throws -> CostData {
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
        let dayKey = Self.dayFmt.string(from: now)

        // 3. 余额反推基础计算
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

        // 4. CSV 快照校准：导入时 snapshot = balance + csvTotalCost ≈ 月初余额
        //    之后 monthlyCost = snapshot - balance（覆盖所有天，无需区分今天/历史）
        if let ud = usageData, ud.totalCost > 0 {
            let snap = AppGroup.csvSnapshotBalance

            // 首次/快照过期：用当前余额 + CSV累计 推算月初基准
            if snap == 0 || newMonth {
                AppGroup.csvSnapshotBalance = balance + ud.totalCost
            } else if delta > 0 {
                // 充值：快照同步上调
                AppGroup.csvSnapshotBalance += delta
            }
        }

        var monthlyCost = max(0, prev.monthStartBalance - balance)
        if let snap = (AppGroup.csvSnapshotBalance > 0 ? AppGroup.csvSnapshotBalance : nil) {
            monthlyCost = max(0, snap - balance)
        }

        if newMonth || prev.monthStartBalance == 0 {
            prev.monthStartBalance = balance
        } else if delta > 0 {
            prev.monthStartBalance += delta
        }

        // 4. 每日记录 — 优先用 CSV 精确数据，余额推断做 fallback
        var costsByDate = Dictionary(uniqueKeysWithValues: prev.dailyCosts.map { ($0.date, $0.amount) })
        let todayStr = Self.fmt.string(from: now)
        costsByDate[todayStr] = todayCost

        // 用 CSV 精确数据覆盖历史日期
        if let ud = usageData {
            for (csvDate, csvCost) in ud.dailyCosts {
                let formatted = Self.csvDateToDisplay(csvDate)
                if formatted != todayStr {
                    costsByDate[formatted] = csvCost
                }
            }
        }

        let dailyCosts = (0..<14).reversed().compactMap { offset -> DailyCost? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let dateString = Self.fmt.string(from: date)
            return DailyCost(date: dateString, amount: costsByDate[dateString] ?? 0)
        }

        // 5. 模型消耗 — 当日按 CSV 当日明细精确拆分
        let modelCosts: [ModelCost] = Self.splitModelCosts(
            amount: todayCost,
            usageData: usageData,
            date: Self.csvDateKey(from: now)
        )

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

    // MARK: - 内置定价 (¥/token, 2026年7月)

    /// 模型定价表 (CNY per token, 空闲时段价)
    static let modelPricing: [String: (cacheHit: Double, cacheMiss: Double, output: Double)] = [
        "deepseek-v4-pro":   (0.000000025, 0.000003, 0.000006),
        "deepseek-v4-flash": (0.000000020, 0.000001, 0.000002),
        // 2026-09-10 上线，取代 v4-flash / vision-exp
        "deepseek-flash":    (0.000000020, 0.000001, 0.000004),
    ]

    /// 根据 token 量和定价表计算费用
    static func computeCost(model: String, cacheHit: Int, cacheMiss: Int, output: Int) -> Double {
        guard let p = modelPricing[model] else { return 0 }
        return Double(cacheHit) * p.cacheHit + Double(cacheMiss) * p.cacheMiss + Double(output) * p.output
    }

    /// 拆分金额到各模型：优先用 CSV 精确值，差值部分按占比补
    /// - date: 传当天日期则按当日明细拆分；不传则按当月累计拆分
    /// 模型列表从 CSV 动态读取，自动适应模型增减（如视觉模型上下线）
    static func splitModelCosts(amount: Double, usageData: ParsedUsageData?, date: String? = nil) -> [ModelCost] {
        guard let ud = usageData, ud.totalCost > 0, !ud.allModels.isEmpty else {
            // 无 CSV 时：用已知模型均分兜底
            let fallback = ["deepseek-v4-pro", "deepseek-v4-flash"]
            let each = amount / Double(fallback.count)
            return fallback.map {
                ModelCost(model: $0, amount: each, percentage: 100.0 / Double(fallback.count), totalTokens: 0)
            }
        }

        let models = ud.allModels

        // 精确部分：当日明细 or 当月累计
        let exact: [String: Double]
        if let date {
            exact = ud.dailyCostsByModel[date] ?? [:]
        } else {
            exact = ud.costByModel
        }
        let extra = max(0, amount - exact.values.reduce(0, +))

        return models.map { model in
            let exactCost = exact[model] ?? 0
            let ratio = ud.modelRatio(model)

            // Token：当日取当日明细，当月取累计
            let tokens: Int
            if let date {
                tokens = ud.tokensFor(date: date, model: model)?.total ?? 0
            } else {
                tokens = ud.tokensByModel[model]?.total ?? 0
            }

            return ModelCost(
                model: model,
                amount: exactCost + extra * ratio,
                percentage: ud.totalCost > 0 ? (exactCost / ud.totalCost * 100) : 0,
                totalTokens: Int64(tokens)
            )
        }.sorted { $0.amount > $1.amount }
    }

    private static func d(_ v: Any?) -> Double {
        guard let v else { return 0 }
        if let n = v as? Double { return n }
        if let s = v as? String, let n = Double(s) { return n }
        return 0
    }

    /// 将 CSV 的 yyyymmdd 格式转成显示格式 MM-dd
    static func csvDateToDisplay(_ yyyymmdd: String) -> String {
        guard yyyymmdd.count == 8 else { return yyyymmdd }
        let m = yyyymmdd.dropFirst(4).prefix(2)
        let d = yyyymmdd.suffix(2)
        return "\(m)-\(d)"
    }

    /// 将 Date 转成 CSV 的 yyyymmdd 格式
    private static func csvDateKey(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: date)
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
