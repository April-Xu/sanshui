import AppKit

// MARK: - 像素风太阳按钮（无笑脸，纯太阳图标）

class SunButton: NSView {
    var onClick: (() -> Void)?
    private var isHovered = false
    private var isPressed = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds

        // 像素风按钮底色
        let bgColor: NSColor = isPressed
            ? NSColor(red: 0.12, green: 0.09, blue: 0.02, alpha: 0.95)
            : (isHovered
                ? NSColor(red: 0.28, green: 0.18, blue: 0.03, alpha: 0.95)
                : NSColor(red: 0.16, green: 0.12, blue: 0.02, alpha: 0.88))
        bgColor.setFill(); b.fill()

        // 像素风边框（2层：亮边 + 暗边）
        NSColor(red: 0.85, green: 0.62, blue: 0.1, alpha: 1).setStroke()
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).lineWidth = 1

        let outer = NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5))
        outer.lineWidth = 1; outer.stroke()

        // 内侧1px高光（左上角）
        NSColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.4).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 1.5, y: b.height-1.5))
        hl.line(to: NSPoint(x: 1.5, y: 1.5))
        hl.line(to: NSPoint(x: b.width-1.5, y: 1.5))
        hl.lineWidth = 1; hl.stroke()

        // 画太阳：中心圆 + 8条射线
        let cx = b.midX, cy = b.midY
        let coreR: CGFloat = 3.5
        let rayInner: CGFloat = coreR + 2.5
        let rayOuter: CGFloat = coreR + 5.5

        let sunColor = NSColor(red: 1, green: 0.82, blue: 0.1, alpha: 1)

        // 射线（8条，像素风1.5px宽）
        sunColor.withAlphaComponent(0.9).setStroke()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let sx = cx + rayInner * cos(angle)
            let sy = cy + rayInner * sin(angle)
            let ex = cx + rayOuter * cos(angle)
            let ey = cy + rayOuter * sin(angle)
            let r = NSBezierPath()
            r.move(to: NSPoint(x: sx, y: sy))
            r.line(to: NSPoint(x: ex, y: ey))
            r.lineWidth = 1.5; r.stroke()
        }

        // 太阳核心圆
        let circle = NSBezierPath(ovalIn: NSRect(
            x: cx - coreR, y: cy - coreR,
            width: coreR*2, height: coreR*2))
        sunColor.setFill(); circle.fill()
        NSColor(red: 0.75, green: 0.45, blue: 0, alpha: 1).setStroke()
        circle.lineWidth = 0.75; circle.stroke()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { isHovered = false; isPressed = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent)    { isPressed = true;  needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        if isPressed { isPressed = false; needsDisplay = true; onClick?() }
    }
}

// MARK: - 持久控制栏（宠物右侧）

class PetControlBar: NSPanel {
    weak var petVC: PetViewController?
    private var sunButton: SunButton?

    static func make(petVC: PetViewController) -> PetControlBar {
        let size = NSSize(width: 26, height: 26)
        let bar = PetControlBar(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        bar.isOpaque = false
        bar.backgroundColor = .clear
        bar.level = .floating
        bar.collectionBehavior = [.canJoinAllSpaces, .stationary]
        bar.hasShadow = false
        bar.petVC = petVC
        bar.setupContent()
        return bar
    }

    private func setupContent() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = v

        let sun = SunButton(frame: NSRect(x: 0, y: 0, width: 26, height: 26))
        sun.onClick = { [weak self] in self?.triggerSunburn() }
        v.addSubview(sun)
        sunButton = sun
    }

    /// 定位到宠物窗口右侧中央
    func positionRight(of petWindow: NSWindow) {
        let pf = petWindow.frame
        let gap: CGFloat = 6
        var x = pf.maxX + gap
        var y = pf.midY - frame.height / 2

        if let screen = NSScreen.main?.visibleFrame {
            if x + frame.width > screen.maxX { x = pf.minX - frame.width - gap }
            y = max(screen.minY, min(screen.maxY - frame.height, y))
        }
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func triggerSunburn() {
        sunButton?.isHidden = true
        let prevState = petVC?.currentState ?? .idle
        petVC?.playOnce(state: .sunburn) { [weak self] in
            self?.petVC?.startAnimation(for: prevState)
            self?.sunButton?.isHidden = false
        }
    }
}
