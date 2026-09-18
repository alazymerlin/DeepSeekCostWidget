import Foundation

/// Codex 用量读取结果 — 区分「没装」「没有数据」「被权限挡住」，供 UI 分别降级
enum CodexResult: Equatable, Sendable {
    case ok(CodexUsage)
    case noCodexDir
    case notFound
    case permissionDenied
}

/// 从本地 Codex 会话文件读取额度用量（5 小时 / 周）
///
/// Codex 每轮对话都会把限流快照写进 `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`，
/// 每条形如：
/// ```
/// "rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,
///   "window_minutes":300,"resets_at":1789715952}, ...}
/// ```
/// 只读文件、不发请求 —— 不消耗额度也不需要 API Key。
///
/// 注意：`~/.codex` 常被软链到 `~/Documents/` 下，而 `~/Documents` 受 macOS TCC 保护，
/// 首次读取会弹权限框；被拒绝后是静默失败，故需单独识别为 `.permissionDenied`。
enum CodexReader {

    /// 只读文件尾部即可覆盖最后一条限流记录 —— 实测 25 个会话（含 534 MB 的）
    /// 最后一条距文件尾最多 14,645 字节，这里留约 17 倍余量
    private static let tailBytes = 256 * 1024

    /// 最新的几个会话可能压根不含限流记录（空会话/中断会话），需依次回退
    private static let maxFilesToScan = 10

    /// 数据目录 —— 与 Codex 一致，优先认 `CODEX_HOME`
    static var codexDir: URL {
        if let custom = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    // MARK: - Entry

    static func load() -> CodexResult {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: codexDir.path, isDirectory: &isDir), isDir.boolValue else {
            return .noCodexDir
        }

        let (files, enumerationFailed) = rolloutFiles()
        if files.isEmpty {
            return enumerationFailed ? .permissionDenied : .notFound
        }

        for file in files.prefix(maxFilesToScan) {
            if let usage = parse(url: file.url, modifiedAt: file.modifiedAt) {
                return .ok(usage)
            }
        }
        return .notFound
    }

    // MARK: - 定位会话文件

    private struct Candidate {
        let url: URL
        let modifiedAt: Date
    }

    /// 收集所有会话文件，按修改时间从新到旧
    ///
    /// 不按目录名（`YYYY/MM/DD`）排序 —— 会话会跨天持续追加，
    /// 9/17 目录下的文件修改时间可能是 9/18。
    private static func rolloutFiles() -> (files: [Candidate], failed: Bool) {
        let fm = FileManager.default
        let roots = [
            codexDir.appendingPathComponent("sessions"),
            codexDir.appendingPathComponent("archived_sessions"),
        ]

        var out: [Candidate] = []
        var failed = false

        for root in roots {
            guard fm.fileExists(atPath: root.path) else { continue }

            var rootFailed = false
            let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
            guard let en = fm.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in
                    // 典型情况：TCC 拒绝读取 ~/Documents
                    rootFailed = true
                    return true
                }
            ) else {
                failed = true
                continue
            }

            for case let url as URL in en where url.pathExtension == "jsonl" {
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile != false else { continue }
                out.append(Candidate(url: url,
                                     modifiedAt: values?.contentModificationDate ?? .distantPast))
            }
            if rootFailed { failed = true }
        }

        out.sort { $0.modifiedAt > $1.modifiedAt }
        return (out, failed)
    }

    // MARK: - 解析单个会话文件

    private static func parse(url: URL, modifiedAt: Date) -> CodexUsage? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let size = try? handle.seekToEnd(), size > 0 else { return nil }
        let offset = size > UInt64(tailBytes) ? size - UInt64(tailBytes) : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd(), !data.isEmpty else { return nil }

        let marker = Data("\"rate_limits\"".utf8)
        var searchEnd = data.count

        // 从尾部往前找。末条可能被截断（文件正在写入），故多试几次
        for _ in 0..<5 {
            guard let found = data.range(of: marker, options: .backwards, in: 0..<searchEnd) else {
                return nil
            }
            if let object = extractObject(data, after: found.upperBound),
               let dto = try? JSONDecoder().decode(RateLimitsDTO.self, from: object),
               let usage = build(dto, modifiedAt: modifiedAt, url: url) {
                return usage
            }
            searchEnd = found.lowerBound
        }
        return nil
    }

    /// 从 `"rate_limits"` 之后取出配平的 `{...}` 对象
    ///
    /// 必须跳过字符串内部的引号与转义 —— 否则 `limit_name` 之类字段会让括号配错。
    private static func extractObject(_ data: Data, after index: Int) -> Data? {
        var i = index
        while i < data.count, data[i] == 0x20 || data[i] == 0x3A || data[i] == 0x09 || data[i] == 0x0A || data[i] == 0x0D {
            i += 1
        }
        guard i < data.count, data[i] == 0x7B else { return nil }  // '{'

        let start = i
        var depth = 0
        var inString = false
        var escaped = false

        while i < data.count {
            let b = data[i]
            if escaped {
                escaped = false
            } else if inString {
                if b == 0x5C { escaped = true }        // '\'
                else if b == 0x22 { inString = false } // '"'
            } else if b == 0x22 {
                inString = true
            } else if b == 0x7B {
                depth += 1
            } else if b == 0x7D {                      // '}'
                depth -= 1
                if depth == 0 { return data.subdata(in: start..<(i + 1)) }
            }
            i += 1
        }
        return nil
    }

    // MARK: - DTO → 领域模型

    private static func build(_ dto: RateLimitsDTO, modifiedAt: Date, url: URL) -> CodexUsage? {
        let primary = dto.primary.flatMap(window)
        let secondary = dto.secondary.flatMap(window)
        guard primary != nil || secondary != nil else { return nil }

        // unlimited 时余额无意义
        var credits: Double?
        if dto.credits?.unlimited != true, let s = dto.credits?.balance {
            credits = Double(s)
        }

        return CodexUsage(
            primary: primary,
            secondary: secondary,
            creditsBalance: credits,
            recordedAt: modifiedAt,
            sourceFile: url.lastPathComponent
        )
    }

    private static func window(_ dto: WindowDTO) -> CodexWindow? {
        guard let resetsAt = dto.resetsAt else { return nil }
        return CodexWindow(
            usedPercent: dto.usedPercent ?? 0,
            windowMinutes: dto.windowMinutes ?? 0,
            resetsAt: Date(timeIntervalSince1970: TimeInterval(resetsAt))
        )
    }

    /// 原样映射外部 JSON —— 键名是 snake_case、时间戳是 epoch 秒、余额是字符串。
    /// 隔一层 DTO，外部格式变动就不会波及 UI 模型。
    private struct RateLimitsDTO: Decodable {
        let primary: WindowDTO?
        let secondary: WindowDTO?
        let credits: CreditsDTO?
    }

    private struct WindowDTO: Decodable {
        let usedPercent: Double?
        let windowMinutes: Int?
        let resetsAt: Int?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }
    }

    private struct CreditsDTO: Decodable {
        let unlimited: Bool?
        let balance: String?
    }
}
