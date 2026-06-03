import AppKit

// MARK: - 像素风太阳按钮

class SunButton: NSView {
    var onClick: (() -> Void)?
    private var isHovered = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let cx = bounds.midX, cy = bounds.midY
        let r: CGFloat = 7    // 太阳半径
        let rayLen: CGFloat = 4
        let rayCount = 8

        let sunColor = isHovered
            ? NSColor(red: 1, green: 0.85, blue: 0, alpha: 1)
            : NSColor(red: 1, green: 0.75, blue: 0.1, alpha: 1)

        // 像素风射线（每条1px宽，向外延伸）
        sunColor.setStroke()
        for i in 0..<rayCount {
            let angle = CGFloat(i) * .pi * 2 / CGFloat(rayCount)
            let startX = cx + (r + 2) * cos(angle)
            let startY = cy + (r + 2) * sin(angle)
            let endX   = cx + (r + 2 + rayLen) * cos(angle)
            let endY   = cy + (r + 2 + rayLen) * sin(angle)
            let ray = NSBezierPath()
            ray.move(to: NSPoint(x: startX, y: startY))
            ray.line(to: NSPoint(x: endX, y: endY))
            ray.lineWidth = 1.5
            ray.stroke()
        }

        // 太阳圆形（填充 + 边框）
        let circle = NSBezierPath(ovalIn: NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
        sunColor.setFill()
        circle.fill()

        // 像素风边框
        NSColor(red: 0.7, green: 0.4, blue: 0, alpha: 1).setStroke()
        circle.lineWidth = 1
        circle.stroke()

        // 小眼睛（像素点）
        NSColor(red: 0.5, green: 0.25, blue: 0, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: cx-3, y: cy-1, width: 2, height: 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx+1, y: cy-1, width: 2, height: 2)).fill()
        // 笑嘴
        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: cx-2.5, y: cy-3))
        smile.curve(to: NSPoint(x: cx+2.5, y: cy-3),
                    controlPoint1: NSPoint(x: cx-1, y: cy-5),
                    controlPoint2: NSPoint(x: cx+1, y: cy-5))
        smile.lineWidth = 1
        NSColor(red: 0.5, green: 0.25, blue: 0, alpha: 1).setStroke()
        smile.stroke()
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { isHovered = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent)    { onClick?() }
}

// MARK: - 持久控制栏

class PetControlBar: NSPanel {
    weak var petVC: PetViewController?
    private var sunButton: SunButton?

    static func make(petVC: PetViewController) -> PetControlBar {
        let bar = PetControlBar(
            contentRect: NSRect(x: 0, y: 0, width: 30, height: 26),
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
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 26))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        contentView = container

        // 像素风背景小框
        let bg = PixelBgView(frame: container.bounds)
        container.addSubview(bg)

        // 太阳按钮
        let sun = SunButton(frame: NSRect(x: 5, y: 5, width: 20, height: 16))
        sun.onClick = { [weak self] in self?.triggerSunburn() }
        container.addSubview(sun)
        sunButton = sun
    }

    func positionBelow(_ petWindow: NSWindow) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        var x = petWindow.frame.midX - frame.width / 2
        var y = petWindow.frame.minY - frame.height - 4
        // 不要掉出屏幕
        x = max(screen.minX, min(screen.maxX - frame.width, x))
        if y < screen.minY { y = petWindow.frame.maxY + 4 }
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func triggerSunburn() {
        // 隐藏按钮
        sunButton?.isHidden = true
        let prevState = petVC?.currentState ?? .idle
        petVC?.playOnce(state: .sunburn) { [weak self] in
            // 播完恢复，显示按钮
            self?.petVC?.startAnimation(for: prevState)
            self?.sunButton?.isHidden = false
        }
    }
}

// MARK: - 像素风背景

private class PixelBgView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // 半透明深色背景 + 白色1px边框
        NSColor(white: 0.1, alpha: 0.7).setFill()
        bounds.fill()
        NSColor.white.withAlphaComponent(0.5).setStroke()
        let p = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        p.lineWidth = 1; p.stroke()
    }
}
