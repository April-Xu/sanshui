import AppKit

// MARK: - 完成时对话气泡

class TokenBubblePanel: NSPanel {

    private static var current: TokenBubblePanel?

    // MARK: - 显示

    static func show(tokens: Int, petWindow: NSWindow) {
        current?.orderOut(nil)
        current = nil
        let panel = TokenBubblePanel(tokens: tokens, petWindow: petWindow)
        current = panel
        panel.orderFront(nil)

        // 4 秒后自动淡出消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak panel] in
            guard let p = panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                p.animator().alphaValue = 0
            }, completionHandler: {
                p.orderOut(nil)
                if TokenBubblePanel.current === p { TokenBubblePanel.current = nil }
            })
        }
    }

    // MARK: - 初始化

    private init(tokens: Int, petWindow: NSWindow) {
        let W: CGFloat = 200, H: CGFloat = 54   // 气泡主体高度（不含尾巴）
        let tailH: CGFloat = 10                   // 尾巴高度
        let totalH = H + tailH

        // 定位：宠物上方
        var x = petWindow.frame.midX - W / 2
        var y = petWindow.frame.maxY + 4
        if let screen = NSScreen.main?.visibleFrame {
            x = max(screen.minX + 4, min(screen.maxX - W - 4, x))
            if y + totalH > screen.maxY { y = petWindow.frame.minY - totalH - 4 }
        }

        super.init(contentRect: NSRect(x: x, y: y, width: W, height: totalH),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = false
        alphaValue = 0

        buildUI(tokens: tokens, W: W, H: H, tailH: tailH)

        // 淡入
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            self.animator().alphaValue = 1
        }
    }

    // MARK: - UI 构建

    private func buildUI(tokens: Int, W: CGFloat, H: CGFloat, tailH: CGFloat) {
        let totalH = H + tailH
        let bubble = BubbleView(frame: NSRect(x: 0, y: 0, width: W, height: totalH),
                                bubbleH: H, tailH: tailH)
        contentView = bubble

        // Emoji 角色
        let emoji = NSTextField(labelWithString: "🐾")
        emoji.frame = NSRect(x: 10, y: totalH - 30, width: 22, height: 22)
        emoji.font = .systemFont(ofSize: 16)
        bubble.addSubview(emoji)

        // 主文字
        let tokenStr = tokens < 1000
            ? "\(tokens)"
            : String(format: "%.1fk", Double(tokens) / 1000)

        let msg = NSTextField(labelWithString: "哥哥我好了！")
        msg.frame = NSRect(x: 36, y: totalH - 26, width: W - 44, height: 18)
        msg.font = .systemFont(ofSize: 12, weight: .semibold)
        msg.textColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        bubble.addSubview(msg)

        let sub = NSTextField(labelWithString: "用了 \(tokenStr) token ✨")
        sub.frame = NSRect(x: 36, y: totalH - 44, width: W - 44, height: 16)
        sub.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        sub.textColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
        bubble.addSubview(sub)
    }
}

// MARK: - 气泡绘制 View（尾巴在下方居中）

private class BubbleView: NSView {
    private let bubbleH: CGFloat
    private let tailH: CGFloat
    private let radius: CGFloat = 10
    private let tailW: CGFloat = 14

    init(frame: NSRect, bubbleH: CGFloat, tailH: CGFloat) {
        self.bubbleH = bubbleH
        self.tailH   = tailH
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let W = bounds.width
        let r = radius
        let tx = W / 2   // 尾巴尖端 x（居中）

        // --- 气泡路径 ---
        let path = NSBezierPath()
        // 从左上角顺时针
        path.move(to: NSPoint(x: r, y: bubbleH))
        path.line(to: NSPoint(x: W - r, y: bubbleH))
        path.appendArc(withCenter: NSPoint(x: W - r, y: bubbleH - r), radius: r,
                       startAngle: 90, endAngle: 0, clockwise: true)
        path.line(to: NSPoint(x: W, y: r))
        path.appendArc(withCenter: NSPoint(x: W - r, y: r), radius: r,
                       startAngle: 0, endAngle: -90, clockwise: true)
        // 右下到尾巴右
        path.line(to: NSPoint(x: tx + tailW / 2, y: 0 + tailH))
        // 尾巴尖端（向下）
        path.line(to: NSPoint(x: tx, y: 0))
        // 尾巴左
        path.line(to: NSPoint(x: tx - tailW / 2, y: 0 + tailH))
        path.line(to: NSPoint(x: r, y: tailH))
        path.appendArc(withCenter: NSPoint(x: r, y: tailH + r), radius: r,
                       startAngle: 270, endAngle: 180, clockwise: true)
        path.line(to: NSPoint(x: 0, y: bubbleH - r))
        path.appendArc(withCenter: NSPoint(x: r, y: bubbleH - r), radius: r,
                       startAngle: 180, endAngle: 90, clockwise: true)
        path.close()

        // 阴影
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()

        // 填充奶白色
        NSColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 0.98).setFill()
        path.fill()

        // 边框（细描边）
        NSShadow().set()   // 清除 shadow 避免边框也有阴影
        NSColor(red: 0.55, green: 0.45, blue: 0.2, alpha: 0.7).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }
}
