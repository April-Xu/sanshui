import Foundation

class QoderStateMonitor {
    static let shared = QoderStateMonitor()

    var onStateChange: ((PetState) -> Void)?
    private(set) var currentState: PetState = .idle

    private var pollTimer: Timer?

    // 记录上次看到的「最新事件时间戳」，避免重复触发旧日志里的事件
    private var lastSeenTimestamp: String = ""
    // 完成/失败后锁定 idle 回归的时间
    private var resetAt: Date? = nil
    // 完成/失败后屏蔽 questWindow 触发的时间（避免旧日志重新触发 coding）
    private var blockQuestUntil: Date = .distantPast
    // streaming 时随机插入 waiting 动画的概率（每次 poll 约 1.5s，概率 ~5%）
    private let waitingFlashChance: Double = 0.05
    private var lastWaitingFlash: Date = .distantPast

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

            let running = self.isQoderRunning()
            guard running else {
                DispatchQueue.main.async { self.transition(to: .idle, from: "not-running") }
                return
            }

            guard let (allLines, questHasNew) = self.recentLogLines(count: 80) else { return }
            let newLines = allLines.filter { $0 > self.lastSeenTimestamp }
            if newLines.isEmpty { return }

            let latest = String(newLines.last?.prefix(23) ?? "")  // 毫秒精度，避免同秒内重复处理
            let event = self.parseEvent(from: newLines, fromQuestWindow: questHasNew)

            DispatchQueue.main.async {
                if !latest.isEmpty { self.lastSeenTimestamp = latest }
                if let event { self.handle(event) }
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
            if currentState == .coding,
               Date().timeIntervalSince(lastWaitingFlash) > 20,
               Double.random(in: 0...1) < waitingFlashChance {
                lastWaitingFlash = Date()
                transition(to: .waiting, from: "random-flash")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                    // 只要还在 waiting（没被其他事件打断）就强制回 coding
                    if self?.currentState == .waiting {
                        self?.transition(to: .coding, from: "random-flash-end")
                    }
                }
                return
            }
            transition(to: .coding, from: "log:streaming")

        case .completed:
            transition(to: .jumping, from: "log:completed")
            resetAt = Date().addingTimeInterval(1.5)
            blockQuestUntil = Date().addingTimeInterval(8)

        case .failed:
            transition(to: .failed, from: "log:failed")
            resetAt = Date().addingTimeInterval(1.5)
            blockQuestUntil = Date().addingTimeInterval(8)

        case .waiting:
            transition(to: .waiting, from: "log:waiting")

        case .thinking:
            transition(to: .thinking, from: "log:thinking")
        }
    }

    // MARK: - 工具

    private func isQoderRunning() -> Bool {
        let t = Process(); t.launchPath = "/usr/bin/pgrep"
        t.arguments = ["-f", "Qoder.app/Contents/MacOS"]
        t.standardOutput = Pipe(); t.standardError = Pipe()
        try? t.run(); t.waitUntilExit()
        return t.terminationStatus == 0
    }

    private func transition(to new: PetState, from source: String) {
        guard new != currentState else { return }
        print("[Monitor] \(currentState) → \(new)  (\(source))")
        currentState = new
        onStateChange?(new)
    }
}

enum LogEvent { case streaming, completed, failed, waiting, thinking }
