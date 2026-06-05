import Foundation

class QoderStateMonitor {
    static let shared = QoderStateMonitor()

    var onStateChange: ((PetState) -> Void)?
    /// streaming 期间实时 token 更新（当前轮次 delta）
    var onLiveTokenUpdate: ((Int) -> Void)?
    /// 完成时回调本轮 completion_tokens（从 DB 读）
    var onCompletionTokens: ((Int) -> Void)?

    private(set) var currentState: PetState = .idle

    private var pollTimer: Timer?

    // 记录上次看到的「最新事件时间戳」，避免重复触发旧日志里的事件
    private var lastSeenTimestamp: String = ""
    // 完成/失败后回 idle 的计时器
    private var resetAt: Date? = nil
    // 完成/失败后屏蔽 questWindow 触发的时间（避免旧日志重新触发 coding）
    private var blockQuestUntil: Date = .distantPast
    // 最后一次看到日志活动的时间（用于替代进程检测）
    private var lastLogActivity: Date = .distantPast
    // 日志静止超过此时间且非 idle → 回 idle（Qoder 关闭或长时间无活动）
    private let logIdleTimeout: TimeInterval = 30
    // 本轮开始时的 usedTokens 基准（prompting 时记录）
    private var turnStartTokens: Int = 0
    // 上次播报的 liveTokens delta（避免重复回调）
    private var lastLiveTokenDelta: Int = -1

    func startMonitoring() {
        // 记录启动时间，只处理启动之后的新日志行
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        lastSeenTimestamp = fmt.string(from: Date())

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func forceState(_ state: PetState) {
        transition(to: state, from: "manual")
    }

    // MARK: - 轮询

    private func poll() {
        // ① reset 计时器必须第一个检查，不依赖有没有新日志
        if let t = resetAt, Date() >= t {
            resetAt = nil
            transition(to: .idle, from: "timer-reset")
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            guard let (allLines, questHasNew) = self.recentLogLines(count: 80) else { return }
            let newLines = allLines.filter { $0 > self.lastSeenTimestamp }

            // 无新日志：距上次活动超 30s 才回 idle，不依赖进程检测
            if newLines.isEmpty {
                DispatchQueue.main.async {
                    if self.currentState != .idle,
                       self.lastLogActivity != .distantPast,
                       Date().timeIntervalSince(self.lastLogActivity) > self.logIdleTimeout {
                        self.transition(to: .idle, from: "log-timeout")
                    }
                }
                return
            }

            let latest = String(newLines.last?.prefix(23) ?? "")  // 毫秒精度，避免同秒内重复处理
            let event = self.parseEvent(from: newLines, fromQuestWindow: questHasNew)

            // 解析实时 token 数
            let liveTokens = self.parseUsedTokens(from: newLines)

            DispatchQueue.main.async {
                if !latest.isEmpty {
                    self.lastSeenTimestamp = latest
                    self.lastLogActivity = Date()
                }
                if let event { self.handle(event) }
                // 播报 token delta（仅 streaming 中）
                if let t = liveTokens, self.currentState == .coding {
                    let delta = max(0, t - self.turnStartTokens)
                    if delta != self.lastLiveTokenDelta {
                        self.lastLiveTokenDelta = delta
                        self.onLiveTokenUpdate?(delta)
                    }
                }
            }
        }
    }

    // MARK: - 日志解析

    // 返回 (allNewLines, questWindowHasNewLines)
    private func recentLogLines(count: Int) -> ([String], Bool)? {
        let base = NSHomeDirectory() + "/Library/Application Support/Qoder/logs"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: base)
            .filter({ !$0.hasPrefix(".") }).sorted().reversed(),
              let latest = dirs.first else { return nil }

        let window1Path = "\(base)/\(latest)/window1/agent.log"
        let questPath   = "\(base)/\(latest)/questWindow/agent.log"

        var allLines: [String] = []
        var questLines: [String] = []

        if let content = try? String(contentsOfFile: window1Path, encoding: .utf8) {
            allLines += content.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        if let content = try? String(contentsOfFile: questPath, encoding: .utf8) {
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            allLines += lines
            questLines = lines
        }

        let sorted = Array(allLines.sorted().suffix(count))
        let questNew = questLines.filter { $0 > lastSeenTimestamp }
        return (sorted, !questNew.isEmpty)
    }

    private func parseEvent(from lines: [String], fromQuestWindow: Bool = false) -> LogEvent? {
        // 最高优先级：完成/失败/取消
        for line in lines.reversed() {
            if line.contains("streaming -> completed") || line.contains("chat_finish:success") {
                return .completed
            }
            if line.contains("streaming -> failed") || line.contains("chat_finish:error")
                || line.contains("streaming -> cancelled") {
                return .failed
            }
        }
        // prompting = 用户刚发消息，Qoder 显示 "Working..."，还没开始输出
        for line in lines.reversed() {
            if line.contains("-> prompting") || line.contains("\"state\":\"prompting\"") {
                return .waiting
            }
        }
        // streaming 中
        if Date() > blockQuestUntil {
            for line in lines.reversed() {
                if line.contains("ACPBlocksService.processProgress")
                    && line.contains("\"state\":\"streaming\"") {
                    return .streaming
                }
            }
        }
        return nil
    }

    // MARK: - 事件处理

    private func handle(_ event: LogEvent) {
        switch event {
        case .streaming:
            // 已在 coding 时，随机偶尔闪一下 waiting 动画（至少间隔 20s）
            transition(to: .coding, from: "log:streaming")

        case .completed:
            transition(to: .jumping, from: "log:completed")
            resetAt = Date().addingTimeInterval(1.5)
            blockQuestUntil = Date().addingTimeInterval(8)
            // 异步读 DB 拿本轮 completion_tokens
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self else { return }
                let ct = self.readCompletionTokensFromDB()
                if ct > 0 {
                    DispatchQueue.main.async { self.onCompletionTokens?(ct) }
                }
            }

        case .failed:
            transition(to: .failed, from: "log:failed")
            resetAt = Date().addingTimeInterval(1.5)
            blockQuestUntil = Date().addingTimeInterval(8)

        case .waiting:
            // prompting：记录当前 usedTokens 基准，重置 delta
            lastLiveTokenDelta = -1
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self else { return }
                let base = self.readLatestUsedTokensFromLog() ?? 0
                DispatchQueue.main.async { self.turnStartTokens = base }
            }
            transition(to: .waiting, from: "log:waiting")

        case .thinking:
            transition(to: .thinking, from: "log:thinking")
        }
    }

    // MARK: - Token 工具

    /// 从新日志行中提取最新 usedTokens
    private func parseUsedTokens(from lines: [String]) -> Int? {
        for line in lines.reversed() {
            if line.contains("Context usage update"),
               let r = line.range(of: "\"usedTokens\":"),
               let end = line[r.upperBound...].firstIndex(where: { !$0.isNumber && $0 != "-" }) {
                return Int(line[r.upperBound..<end])
            }
        }
        return nil
    }

    /// 读 agent.log 中最近一条 Context usage update 的 usedTokens（基准用）
    private func readLatestUsedTokensFromLog() -> Int? {
        let base = NSHomeDirectory() + "/Library/Application Support/Qoder/logs"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: base)
            .filter({ !$0.hasPrefix(".") }).sorted().reversed(),
              let latest = dirs.first else { return nil }
        let path = "\(base)/\(latest)/window1/agent.log"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: "\n").filter { $0.contains("Context usage update") }
        return lines.compactMap { line -> Int? in
            guard let r = line.range(of: "\"usedTokens\":"),
                  let end = line[r.upperBound...].firstIndex(where: { !$0.isNumber && $0 != "-" }) else { return nil }
            return Int(line[r.upperBound..<end])
        }.last
    }

    /// 从 Qoder DB 读最新 assistant 消息的 completion_tokens
    private func readCompletionTokensFromDB() -> Int {
        let dbPath = NSHomeDirectory() + "/Library/Application Support/Qoder/SharedClientCache/cache/db/local.db"
        // 用 sqlite3 命令行避免引入 SQLite 依赖
        let task = Process()
        task.launchPath = "/usr/bin/sqlite3"
        task.arguments = [dbPath,
            "SELECT token_info FROM chat_message WHERE role='assistant' AND token_info IS NOT NULL ORDER BY gmt_create DESC LIMIT 1;"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return 0 }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return 0 }
        // token_info 示例：{"prompt_tokens":145415,"completion_tokens":2813,...}
        let json = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = json.range(of: "\"completion_tokens\":"),
           let end = json[r.upperBound...].firstIndex(where: { !$0.isNumber }) {
            return Int(json[r.upperBound..<end]) ?? 0
        }
        return 0
    }

    // MARK: - 工具

    private func transition(to new: PetState, from source: String) {
        guard new != currentState else { return }
        print("[Monitor] \(currentState) → \(new)  (\(source))")
        currentState = new
        onStateChange?(new)
    }
}

enum LogEvent { case streaming, completed, failed, waiting, thinking }
