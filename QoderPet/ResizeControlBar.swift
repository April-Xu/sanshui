import AppKit

// MARK: - 像素风按钮

class PixelButton: NSButton {
    var bgColor: NSColor = .black
    var borderColor: NSColor = NSColor.white.withAlphaComponent(0.8)
    var labelColor: NSColor = .white

    override func draw(_ dirtyRect: NSRect) {
        // 背景
        bgColor.setFill()
        bounds.fill()
        // 外边框
        borderColor.setStroke()
        let outer = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        outer.lineWidth = 1; outer.stroke()
        // 左上高光
        NSColor.white.withAlphaComponent(0.3).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 1, y: bounds.height - 1))
        hl.line(to: NSPoint(x: 1, y: 1))
        hl.line(to: NSPoint(x: bounds.width - 1, y: 1))
        hl.lineWidth = 1; hl.stroke()
        // 文字
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: labelColor,
            .paragraphStyle: para
        ]
        let r = NSRect(x: 0, y: (bounds.height - 11) / 2, width: bounds.width, height: 11)
        (title as NSString).draw(in: r, withAttributes: attrs)
    }
}

// MARK: - Handle 覆盖 NSView（用 draw 绘制，坐标系和事件完全一致）

class HandleOverlayView: NSView {
    let handleSize: CGFloat = 8

    // 8 handle 归一化位置（NSView 坐标，y=0 在底部）
    let positions: [(CGFloat, CGFloat)] = [
        (0,   0  ), (0.5, 0  ), (1,   0  ),   // 底左、底中、底右
        (0,   0.5),              (1,   0.5),   // 左中、右中
        (0,   1  ), (0.5, 1  ), (1,   1  ),   // 顶左、顶中、顶右
    ]

    func handleRect(at i: Int) -> NSRect {
        let (nx, ny) = positions[i]
        let x = nx * (bounds.width  - handleSize)
        let y = ny * (bounds.height - handleSize)
        return NSRect(x: x, y: y, width: handleSize, height: handleSize)
    }

    func hitHandle(_ loc: NSPoint) -> Int {
        let pad: CGFloat = 5
        for i in 0..<positions.count {
            if handleRect(at: i).insetBy(dx: -pad, dy: -pad).contains(loc) { return i }
        }
        return -1
    }

    override var isFlipped: Bool { false }

    // 事件穿透：所有鼠标事件由 superview (PetContainerView) 处理
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }

    override func draw(_ dirtyRect: NSRect) {
        // 白色虚线边框
        NSColor.white.withAlphaComponent(0.85).setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 1
        let dash: [CGFloat] = [4, 3]
        border.setLineDash(dash, count: 2, phase: 0)
        border.stroke()

        // 8个 handle 方块
        for i in 0..<positions.count {
            let r = handleRect(at: i)
            NSColor.white.setFill(); r.fill()
            NSColor.systemBlue.setStroke()
            let p = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
            p.lineWidth = 1; p.stroke()
        }
    }
}

// MARK: - 控制栏

class ResizeControlBar: NSPanel {
    var onConfirm: (() -> Void)?
    var onCancel:  (() -> Void)?
    var onReset:   (() -> Void)?

    static func makeBar() -> ResizeControlBar {
        let bar = ResizeControlBar(
            contentRect: NSRect(x: 0, y: 0, width: 106, height: 22),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        bar.isOpaque = false
        bar.backgroundColor = .clear
        bar.level = .floating
        bar.collectionBehavior = [.canJoinAllSpaces, .stationary]
        bar.hasShadow = false
        bar.setupButtons()
        return bar
    }

    private func setupButtons() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 106, height: 22))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = view

        func btn(_ title: String, bg: NSColor, x: CGFloat) -> PixelButton {
            let b = PixelButton(frame: NSRect(x: x, y: 0, width: 32, height: 22))
            b.title = title; b.bgColor = bg; b.isBordered = false
            return b
        }

        let confirm = btn("✓", bg: NSColor(red:0.1,green:0.45,blue:0.1,alpha:1), x: 0)
        confirm.target = self; confirm.action = #selector(didConfirm)

        let reset = btn("↺", bg: NSColor(white:0.28,alpha:1), x: 37)
        reset.target = self; reset.action = #selector(didReset)

        let cancel = btn("✕", bg: NSColor(red:0.5,green:0.1,blue:0.1,alpha:1), x: 74)
        cancel.target = self; cancel.action = #selector(didCancel)

        [confirm, reset, cancel].forEach { view.addSubview($0) }
    }

    func position(below petWindow: NSWindow) {
        let pf = petWindow.frame
        setFrameOrigin(NSPoint(x: pf.midX - frame.width/2, y: pf.minY - frame.height - 4))
    }

    @objc private func didConfirm() { onConfirm?() }
    @objc private func didReset()   { onReset?() }
    @objc private func didCancel()  { onCancel?() }
}
