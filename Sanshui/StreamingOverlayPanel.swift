import AppKit

// MARK: - 明亮像素风 Streaming 浮层

class StreamingOverlayPanel: NSPanel {

    static var current: StreamingOverlayPanel?

    private weak var petWindow: NSWindow?
    private var tokenLabel: NSTextField!
    private var dotTimer: Timer?
    private var dotCount = 0
    private var dotLabel: NSTextField!
    private var replyField: PixelTextField!
    private var moveObserver: Any?

    // MARK: - 显示 / 隐藏

    static func show(petWindow: NSWindow) {
        if let c = current, c.petWindow === petWindow { return } // 已显示
        current?.dismiss()
        let panel = StreamingOverlayPanel(petWindow: petWindow)
        current = panel
        panel.orderFront(nil)
    }

    static func hide() {
        current?.dismiss()
        current = nil
    }

    // MARK: - 初始化

    private init(petWindow: NSWindow) {
        self.petWindow = petWindow
        let W: CGFloat = 230, H: CGFloat = 82
        super.init(contentRect: NSRect(x: 0, y: 0, width: W, height: H),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = true
        // 允许成为 key window，让输入框能接收键盘事件
        becomesKeyOnlyIfNeeded = false

        buildUI(W: W, H: H)
        reposition()

        // 跟随宠物窗口移动
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: petWindow, queue: .main) { [weak self] _ in
            self?.reposition()
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: petWindow, queue: .main) { [weak self] _ in
            self?.reposition()
        }

        startDotAnimation()
    }

    deinit {
        dotTimer?.invalidate()
        if let obs = moveObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - UI 构建（明亮像素风）

    private func buildUI(W: CGFloat, H: CGFloat) {
        let cv = BrightPixelBgView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        contentView = cv

        // 标题行
        let title = NSTextField(labelWithString: "⌨ Agent 输出中")
        title.frame = NSRect(x: 8, y: H - 18, width: 130, height: 14)
        title.font = .monospacedSystemFont(ofSize: 10, weight: .bold)
        title.textColor = NSColor(red: 0.1, green: 0.35, blue: 0.1, alpha: 1)
        cv.addSubview(title)

        // 动态省略号
        dotLabel = NSTextField(labelWithString: "●●●")
        dotLabel.frame = NSRect(x: 140, y: H - 18, width: 50, height: 14)
        dotLabel.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        dotLabel.textColor = NSColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.8)
        dotLabel.alignment = .right
        cv.addSubview(dotLabel)

        // Token 计数
        tokenLabel = NSTextField(labelWithString: "▶ 0 tokens")
        tokenLabel.frame = NSRect(x: 8, y: H - 34, width: W - 16, height: 13)
        tokenLabel.font = .monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        tokenLabel.textColor = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        cv.addSubview(tokenLabel)

        // 回复输入框
        replyField = PixelTextField(frame: NSRect(x: 8, y: 22, width: W - 60, height: 20))
        replyField.font = .systemFont(ofSize: 10)
        replyField.placeholderString = "回复 Agent…"
        replyField.target = self
        replyField.action = #selector(sendReply)
        cv.addSubview(replyField)

        // 发送按钮
        let sendBtn = BrightPixelBtn(title: "发送", bg: NSColor(red: 0.15, green: 0.5, blue: 0.15, alpha: 1))
        sendBtn.frame = NSRect(x: W - 50, y: 22, width: 42, height: 20)
        sendBtn.onClick = { [weak self] in self?.sendReply() }
        cv.addSubview(sendBtn)

        // 提示文字
        let hint = NSTextField(labelWithString: "⏎ 发送 · 回复后 Agent 继续工作")
        hint.frame = NSRect(x: 8, y: 6, width: W - 16, height: 12)
        hint.font = .systemFont(ofSize: 8)
        hint.textColor = NSColor(white: 0.5, alpha: 1)
        cv.addSubview(hint)
    }

    // MARK: - 更新 token 数

    func updateTokens(_ delta: Int) {
        let txt = delta < 1000
            ? "▶ \(delta) tokens"
            : "▶ \(String(format: "%.1f", Double(delta)/1000))k tokens"
        tokenLabel?.stringValue = txt
    }

    // MARK: - 点状动画

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.dotCount = (self.dotCount + 1) % 4
            let dots = String(repeating: "●", count: self.dotCount) + String(repeating: "○", count: 3 - self.dotCount)
            self.dotLabel?.stringValue = dots
        }
    }

    // MARK: - 发送回复

    @objc private func sendReply() {
        let text = replyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        replyField.stringValue = ""

        // 把文本写到剪贴板，然后激活 Qoder 并 Cmd+V
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        let script = """
        tell application "Qoder" to activate
        delay 0.25
        tell application "System Events"
            keystroke "v" using command down
            key code 36
        end tell
        """
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        // 发完把 key 交还给宠物窗口，不持续抢占焦点
        petWindow?.makeKey()
    }

    // MARK: - 定位

    private func reposition() {
        guard let pw = petWindow else { return }
        let W = frame.width, H = frame.height
        var x = pw.frame.midX - W / 2
        var y = pw.frame.maxY + 8
        // 跟随宠物所在的显示器
        let center = CGPoint(x: pw.frame.midX, y: pw.frame.midY)
        let screen = (NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.main)?.visibleFrame
        if let s = screen {
            x = max(s.minX + 4, min(s.maxX - W - 4, x))
            if y + H > s.maxY { y = pw.frame.minY - H - 8 }
        }
        setFrameOrigin(CGPoint(x: x, y: y))
    }

    // 允许成为 key window，输入框才能打字
    override var canBecomeKey: Bool { true }

    func dismiss() {
        dotTimer?.invalidate()
        if let obs = moveObserver { NotificationCenter.default.removeObserver(obs); moveObserver = nil }
        orderOut(nil)
    }
}

// MARK: - 明亮像素风背景

private class BrightPixelBgView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // 奶油黄底
        NSColor(red: 0.98, green: 0.97, blue: 0.88, alpha: 0.97).setFill()
        b.fill()
        // 外层深绿边框（像素风）
        NSColor(red: 0.15, green: 0.42, blue: 0.15, alpha: 1).setStroke()
        let outer = NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5))
        outer.lineWidth = 2
        outer.stroke()
        // 内层浅高光（右下）
        NSColor(red: 0.6, green: 0.85, blue: 0.6, alpha: 0.6).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 3, y: b.height - 3))
        hl.line(to: NSPoint(x: 3, y: 3))
        hl.line(to: NSPoint(x: b.width - 3, y: 3))
        hl.lineWidth = 1
        hl.stroke()
        // 分割线（输入区上方）
        NSColor(red: 0.15, green: 0.42, blue: 0.15, alpha: 0.4).setStroke()
        let div = NSBezierPath()
        div.move(to: NSPoint(x: 4, y: 46))
        div.line(to: NSPoint(x: b.width - 4, y: 46))
        div.lineWidth = 1
        div.stroke()
    }
}

// MARK: - 明亮像素风按钮

private class BrightPixelBtn: NSView {
    var title: String
    var bgColor: NSColor
    var onClick: (() -> Void)?
    private var hovered = false
    private var pressed = false

    init(title: String, bg: NSColor) {
        self.title = title; self.bgColor = bg
        super.init(frame: .zero)
        wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        let fill = pressed ? bgColor.blended(withFraction: 0.35, of: .black)! :
                   hovered ? bgColor.blended(withFraction: 0.2,  of: .white)! : bgColor
        fill.setFill(); b.fill()
        NSColor(white: 0.1, alpha: 1).setStroke()
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).lineWidth = 1.5
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).stroke()
        NSColor.white.withAlphaComponent(pressed ? 0 : 0.5).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 2, y: b.height - 2))
        hl.line(to: NSPoint(x: 2, y: 2))
        hl.line(to: NSPoint(x: b.width - 2, y: 2))
        hl.lineWidth = 1; hl.stroke()
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
        (title as NSString).draw(in: NSRect(x: 0, y: (b.height - 13) / 2, width: b.width, height: 13), withAttributes: attr)
    }

    override func mouseEntered(with event: NSEvent) { hovered = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovered = false; pressed = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent)    { pressed = true;  needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        guard pressed else { return }; pressed = false; needsDisplay = true; onClick?()
    }
}

// MARK: - 像素风输入框

class PixelTextField: NSTextField {
    override func awakeFromNib() { super.awakeFromNib(); styleIt() }
    override init(frame: NSRect) { super.init(frame: frame); styleIt() }
    required init?(coder: NSCoder) { super.init(coder: coder); styleIt() }

    private func styleIt() {
        wantsLayer = true
        layer?.borderColor = NSColor(red: 0.15, green: 0.42, blue: 0.15, alpha: 1).cgColor
        layer?.borderWidth = 1.5
        layer?.backgroundColor = NSColor.white.cgColor
        isBezeled = false
        isBordered = false
        drawsBackground = true
        backgroundColor = .white
        focusRingType = .none
    }

    // 点击输入框时让所在 panel 成为 key window，这样才能打字
    override func mouseDown(with event: NSEvent) {
        if let panel = window, !panel.isKeyWindow {
            panel.makeKey()
            panel.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }
}
