import Foundation

// MARK: - CSV Raw Record

struct CSVUsageRecord: Codable {
    let date: String          // "20260616"
    let model: String
    let cost: Double          // CNY
    let inputCacheHitTokens: Int
    let inputCacheMissTokens: Int
    let outputTokens: Int
}

// MARK: - Parsed Usage Data

struct ParsedUsageData: Codable {
    var records: [CSVUsageRecord]
    var totalCost: Double
    var costByModel: [String: Double]
    var tokensByModel: [String: TokenBreakdown]
    var dailyCosts: [String: Double]       // date -> total cost
    var dailyCostsByModel: [String: [String: Double]] // date -> model -> cost
    var dailyTokensByModel: [String: [String: TokenBreakdown]] = [:] // date -> model -> tokens
    var lastImportDate: Date
    var csvStartDate: String
    var csvEndDate: String

    struct TokenBreakdown: Codable {
        var cacheHit: Int = 0
        var cacheMiss: Int = 0
        var output: Int = 0
        var total: Int { cacheHit + cacheMiss + output }
    }

    static let empty = ParsedUsageData(
        records: [],
        totalCost: 0,
        costByModel: [:],
        tokensByModel: [:],
        dailyCosts: [:],
        dailyCostsByModel: [:],
        dailyTokensByModel: [:],
        lastImportDate: .distantPast,
        csvStartDate: "",
        csvEndDate: ""
    )

    /// 指定日期的模型 token 用量
    func tokensFor(date: String, model: String) -> TokenBreakdown? {
        dailyTokensByModel[date]?[model]
    }

    /// CSV 中出现过的所有模型（按总费用降序）
    var allModels: [String] {
        costByModel.keys.sorted { (costByModel[$0] ?? 0) > (costByModel[$1] ?? 0) }
    }

    // MARK: - Computed

    /// 指定日期的总费用（从CSV）
    func costFor(dateStr: String) -> Double {
        dailyCosts[dateStr] ?? 0
    }

    /// 指定月份的总费用
    func costForMonth(_ yearMonth: String) -> Double {
        dailyCosts.filter { $0.key.hasPrefix(yearMonth) }.values.reduce(0, +)
    }

    /// 模型费用占比
    func modelRatio(_ model: String) -> Double {
        guard totalCost > 0 else { return 0 }
        return (costByModel[model] ?? 0) / totalCost
    }

    /// 某日期的模型费用明细
    func modelCostsFor(dateStr: String) -> [ModelCost] {
        guard let dayData = dailyCostsByModel[dateStr] else { return [] }
        return dayData.map { model, cost in
            let tokens = tokensByModel[model]
            return ModelCost(
                model: model,
                amount: cost,
                percentage: totalCost > 0 ? (cost / totalCost * 100) : 0,
                totalTokens: Int64(tokens?.total ?? 0)
            )
        }.sorted { $0.amount > $1.amount }
    }

    /// 累计模型费用（从CSV开始到最新数据）
    func cumulativeModelCosts() -> [ModelCost] {
        costByModel.map { model, cost in
            let tokens = tokensByModel[model]
            return ModelCost(
                model: model,
                amount: cost,
                percentage: totalCost > 0 ? (cost / totalCost * 100) : 0,
                totalTokens: Int64(tokens?.total ?? 0)
            )
        }.sorted { $0.amount > $1.amount }
    }
}

// MARK: - CSV Parser

enum UsageCSV {
    /// 统一日期格式为 yyyyMMdd
    /// 旧格式: "20260616"
    /// 新格式: "2026-09-01T00:00:00+08:00"
    static func normalizeDate(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.count == 8, s.allSatisfy({ $0.isNumber }) { return s }
        if s.count >= 10, s.contains("-") {
            let parts = s.prefix(10).split(separator: "-")
            guard parts.count == 3 else { return nil }
            return "\(parts[0])\(parts[1])\(parts[2])"
        }
        return nil
    }

    /// 模型名归一化
    /// 2026-09 官方把视觉模型(vision-exp)合并进 Flash，历史数据统一归并
    static func normalizeModel(_ raw: String) -> String {
        switch raw {
        case "deepseek-v4-flash-vision-exp":
            return "deepseek-v4-flash"
        default:
            return raw
        }
    }

    /// 定位日期列：兼容 utc_date（旧）和 start_time_iso（新）
    private static func dateColumnIndex(_ header: [String]) -> Int {
        header.firstIndex { $0.hasSuffix("utc_date") || $0.hasSuffix("start_time_iso") } ?? 1
    }

    /// Parse DeepSeek exported cost.csv and amount.csv
    static func parse(costCSV: String, amountCSV: String) -> ParsedUsageData {
        struct TokenRow {
            let date, model, type: String
            let amount: Int
        }
        var tokenRows: [TokenRow] = []
        var dateSet = Set<String>()

        // ── amount.csv ──
        // 旧: user_id,utc_date,model,api_key_name,api_key,type,price,amount
        // 新: user_id,start_time_iso,end_time_iso,model,api_key_name,api_key,type,price,amount
        let amountLines = amountCSV.components(separatedBy: .newlines)
        guard amountLines.count > 1 else { return .empty }
        let amountHeader = amountLines[0].components(separatedBy: ",")
        let aDateIdx = dateColumnIndex(amountHeader)
        let aModelIdx = amountHeader.firstIndex { $0 == "model" } ?? 2
        let aTypeIdx = amountHeader.firstIndex { $0 == "type" } ?? 5
        let aAmountIdx = amountHeader.firstIndex { $0 == "amount" } ?? 7

        for line in amountLines.dropFirst() where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count > max(aTypeIdx, aAmountIdx) else { continue }
            let type = cols[aTypeIdx]
            guard type != "request_count", !type.isEmpty else { continue }
            let amount = Int(cols[aAmountIdx]) ?? 0
            guard amount > 0 else { continue }
            guard let date = normalizeDate(cols[aDateIdx]) else { continue }
            let model = normalizeModel(cols[aModelIdx])
            tokenRows.append(TokenRow(date: date, model: model, type: type, amount: amount))
            dateSet.insert(date)
        }

        // ── cost.csv ──
        // 旧: user_id,utc_date,model,wallet_type,cost,currency
        // 新: user_id,start_time_iso,end_time_iso,model,wallet_type,cost,currency
        var records: [CSVUsageRecord] = []
        var dailyCosts: [String: Double] = [:]
        var dailyCostsByModel: [String: [String: Double]] = [:]
        var costByModel: [String: Double] = [:]
        var totalCost: Double = 0

        let costLines = costCSV.components(separatedBy: .newlines)
        guard costLines.count > 1 else { return .empty }
        let costHeader = costLines[0].components(separatedBy: ",")
        let cDateIdx = dateColumnIndex(costHeader)
        let cModelIdx = costHeader.firstIndex { $0 == "model" } ?? 2
        let cCostIdx = costHeader.firstIndex { $0 == "cost" } ?? 4

        for line in costLines.dropFirst() where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count > max(cCostIdx, cDateIdx) else { continue }
            guard let date = normalizeDate(cols[cDateIdx]) else { continue }
            let model = normalizeModel(cols[cModelIdx])
            let cost = Double(cols[cCostIdx]) ?? 0
            guard cost > 0 else { continue }

            totalCost += cost
            costByModel[model, default: 0] += cost
            dailyCosts[date, default: 0] += cost
            dailyCostsByModel[date, default: [:]][model, default: 0] += cost
        }

        // ── 聚合 token ──
        var tokensByModel: [String: ParsedUsageData.TokenBreakdown] = [:]
        var dailyTokensByModel: [String: [String: ParsedUsageData.TokenBreakdown]] = [:]

        for tr in tokenRows {
            // 全量累计
            var tb = tokensByModel[tr.model] ?? ParsedUsageData.TokenBreakdown()
            // 当日明细
            var dayTb = dailyTokensByModel[tr.date]?[tr.model] ?? ParsedUsageData.TokenBreakdown()
            switch tr.type {
            case "input_cache_hit_tokens": tb.cacheHit += tr.amount; dayTb.cacheHit += tr.amount
            case "input_cache_miss_tokens": tb.cacheMiss += tr.amount; dayTb.cacheMiss += tr.amount
            case "output_tokens": tb.output += tr.amount; dayTb.output += tr.amount
            default: break
            }
            tokensByModel[tr.model] = tb
            dailyTokensByModel[tr.date, default: [:]][tr.model] = dayTb
        }

        // ── 构建记录 ──
        let sortedDates = dateSet.sorted()
        for date in sortedDates {
            for (model, cost) in dailyCostsByModel[date] ?? [:] {
                let tokens = dailyTokensByModel[date]?[model] ?? ParsedUsageData.TokenBreakdown()
                records.append(CSVUsageRecord(
                    date: date, model: model, cost: cost,
                    inputCacheHitTokens: tokens.cacheHit,
                    inputCacheMissTokens: tokens.cacheMiss,
                    outputTokens: tokens.output
                ))
            }
        }

        return ParsedUsageData(
            records: records,
            totalCost: totalCost,
            costByModel: costByModel,
            tokensByModel: tokensByModel,
            dailyCosts: dailyCosts,
            dailyCostsByModel: dailyCostsByModel,
            dailyTokensByModel: dailyTokensByModel,
            lastImportDate: Date(),
            csvStartDate: sortedDates.first ?? "",
            csvEndDate: sortedDates.last ?? ""
        )
    }
}
