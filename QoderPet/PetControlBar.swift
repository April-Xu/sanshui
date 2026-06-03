import AppKit

// MARK: - 星露谷风格太阳按钮

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

        // 按钮底色：暖奶油黄（星露谷 UI 风格）
        let bg: NSColor = isPressed
            ? NSColor(red: 0.97, green: 0.82, blue: 0.38, alpha: 1)
            : (isHovered
                ? NSColor(red: 1.0,  green: 0.94, blue: 0.60, alpha: 1)
                : NSColor(red: 0.99, green: 0.90, blue: 0.52, alpha: 1))
        bg.setFill(); b.fill()

        // 像素风边框：外层深棕，内层亮高光
        NSColor(red: 0.45, green: 0.28, blue: 0.05, alpha: 1).setStroke()
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).lineWidth = 1.5
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).stroke()

        // 左上内侧高光（白色1px，星露谷UI特征）
        NSColor.white.withAlphaComponent(isPressed ? 0 : 0.7).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 2, y: b.height-2)); hl.line(to: NSPoint(x: 2, y: 2))
        hl.line(to: NSPoint(x: b.width-2, y: 2))
        hl.lineWidth = 1; hl.stroke()

        // 右下内侧暗边
        NSColor(red: 0.35, green: 0.20, blue: 0.02, alpha: 0.5).setStroke()
        let sh = NSBezierPath()
        sh.move(to: NSPoint(x: b.width-2, y: 2))
        sh.line(to: NSPoint(x: b.width-2, y: b.height-2))
        sh.line(to: NSPoint(x: 2, y: b.height-2))
        sh.lineWidth = 1; sh.stroke()

        // ── 太阳 ──
        let cx = b.midX + (isPressed ? 0.5 : 0)
        let cy = b.midY - (isPressed ? 0.5 : 0)
        let coreR: CGFloat  = 4.5
        let rayNear: CGFloat = coreR + 2.5
        let rayFar: CGFloat  = coreR + 5.5

        // 射线（8条，2px粗，深橙色轮廓 + 亮黄填充）
        for i in 0..<8 {
            let a = CGFloat(i) * .pi / 4 + .pi/8
            // 粗射线（深色）
            NSColor(red: 0.80, green: 0.45, blue: 0.02, alpha: 1).setStroke()
            let thick = NSBezierPath()
            thick.move(to: NSPoint(x: cx + rayNear*cos(a), y: cy + rayNear*sin(a)))
            thick.line(to: NSPoint(x: cx + rayFar*cos(a),  y: cy + rayFar*sin(a)))
            thick.lineWidth = 3; thick.stroke()
            // 细射线（亮色中线）
            NSColor(red: 1, green: 0.92, blue: 0.3, alpha: 1).setStroke()
            let thin = NSBezierPath()
            thin.move(to: NSPoint(x: cx + (rayNear+0.5)*cos(a), y: cy + (rayNear+0.5)*sin(a)))
            thin.line(to: NSPoint(x: cx + (rayFar-0.5)*cos(a),  y: cy + (rayFar-0.5)*sin(a)))
            thin.lineWidth = 1; thin.stroke()
        }

        // 太阳核心：深橙描边 + 亮橙填充 + 内高光
        let ring = NSBezierPath(ovalIn: NSRect(x: cx-coreR-1, y: cy-coreR-1,
                                               width: (coreR+1)*2, height: (coreR+1)*2))
        NSColor(red: 0.80, green: 0.45, blue: 0.02, alpha: 1).setFill(); ring.fill()

        let core = NSBezierPath(ovalIn: NSRect(x: cx-coreR, y: cy-coreR,
                                               width: coreR*2, height: coreR*2))
        NSColor(red: 1.0, green: 0.75, blue: 0.15, alpha: 1).setFill(); core.fill()

        // 核心内高光（左上小白圆）
        NSColor.white.withAlphaComponent(0.55).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx-coreR+1.5, y: cy+0.5, width: 2.5, height: 2.5)).fill()
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
        let bar = PetControlBar(
            contentRect: NSRect(x: 0, y: 0, width: 28, height: 28),
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
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 28, height: 28))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = v

        let sun = SunButton(frame: v.bounds)
        sun.onClick = { [weak self] in self?.triggerSunburn() }
        v.addSubview(sun)
        sunButton = sun
    }

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
