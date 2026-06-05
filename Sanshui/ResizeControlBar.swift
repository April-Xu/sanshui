import AppKit

// MARK: - 像素风按钮

class PixelBtn: NSView {
    var title: String
    var bgColor: NSColor
    var onClick: (() -> Void)?
    private var hovered = false
    private var pressed = false

    init(title: String, bg: NSColor) {
        self.title = title
        self.bgColor = bg
        super.init(frame: .zero)
        wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // 背景
        let fill = pressed ? bgColor.blended(withFraction: 0.35, of: .black)! :
                   hovered ? bgColor.blended(withFraction: 0.15, of: .white)! : bgColor
        fill.setFill(); b.fill()
        // 像素边框：外深内亮
        NSColor(white: 0.1, alpha: 1).setStroke()
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).lineWidth = 1.5
        NSBezierPath(rect: b.insetBy(dx: 0.5, dy: 0.5)).stroke()
        NSColor.white.withAlphaComponent(pressed ? 0 : 0.45).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x: 2, y: b.height-2))
        hl.line(to: NSPoint(x: 2, y: 2))
        hl.line(to: NSPoint(x: b.width-2, y: 2))
        hl.lineWidth = 1; hl.stroke()
        // 文字
        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para
        ]
        let r = NSRect(x: 0, y: (b.height-13)/2, width: b.width, height: 13)
        (title as NSString).draw(in: r, withAttributes: attr)
    }

    override func mouseEntered(with event: NSEvent) { hovered = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovered = false; pressed = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent)    { pressed = true;  needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        guard pressed else { return }
        pressed = false; needsDisplay = true; onClick?()
    }
}

// MARK: - 像素风调整大小 HUD

class ResizeHUD: NSPanel {
    private static var current: ResizeHUD?

    private weak var petWindow: NSWindow?
    private weak var petVC: PetViewController?
    private let minH: CGFloat = 16
    private let maxH: CGFloat = 200
    private let ratio: CGFloat = 192.0 / 208.0
    private var startH: CGFloat = 0
    private var startCX: CGFloat = 0
    private var startCY: CGFloat = 0
    private var slider: NSSlider!
    private var sizeLabel: NSTextField!
    private var globalMonitor: Any?

    static func show(petWindow: NSWindow, petVC: PetViewController) {
        current?.dismiss(confirm: false)
        let hud = ResizeHUD(petWindow: petWindow, petVC: petVC)
        current = hud
        hud.orderFront(nil)
    }

    private init(petWindow: NSWindow, petVC: PetViewController) {
        self.petWindow = petWindow
        self.petVC = petVC
        self.startH  = petWindow.frame.height
        self.startCX = petWindow.frame.midX
        self.startCY = petWindow.frame.midY

        // HUD 尺寸
        let W: CGFloat = 200, H: CGFloat = 62
        let pf = petWindow.frame
        // 优先放宠物下方，不够就放上方
        var x = pf.midX - W/2
        var y = pf.minY - H - 8
        if let screen = NSScreen.main?.visibleFrame {
            if y < screen.minY { y = pf.maxY + 8 }
            x = max(screen.minX + 4, min(screen.maxX - W - 4, x))
        }

        super.init(contentRect: NSRect(x: x, y: y, width: W, height: H),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = true

        buildUI()
        petVC.animationTimer?.invalidate()  // 冻结动画

        // 点击宠物外面 → 取消
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.dismiss(confirm: false)
        }
    }

    private func buildUI() {
        let W = contentRect(forFrameRect: frame).width
        let H = contentRect(forFrameRect: frame).height
        let cv = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))
        cv.wantsLayer = true
        contentView = cv

        // 像素风背景
        let bg = PixelBgView(frame: cv.bounds)
        cv.addSubview(bg)

        // 尺寸标签
        sizeLabel = NSTextField(labelWithString: "\(Int(startH)) px")
        sizeLabel.frame = NSRect(x: W/2-22, y: H-18, width: 44, height: 14)
        sizeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        sizeLabel.textColor = NSColor(red:1, green:0.92, blue:0.6, alpha:1)
        sizeLabel.alignment = .center
        cv.addSubview(sizeLabel)

        // 滑块
        slider = NSSlider(frame: NSRect(x: 8, y: H-36, width: W-16, height: 20))
        slider.minValue = Double(minH)
        slider.maxValue = Double(maxH)
        slider.doubleValue = Double(startH)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        cv.addSubview(slider)

        // 三个像素风按钮
        let btnW: CGFloat = 52, btnH: CGFloat = 20, gap: CGFloat = 6
        let totalW = btnW*3 + gap*2
        let bx = (W - totalW) / 2
        let by: CGFloat = 6

        let reset  = PixelBtn(title: "↺ 重置",  bg: NSColor(white: 0.32, alpha: 1))
        let confirm = PixelBtn(title: "✓ 确认", bg: NSColor(red:0.15, green:0.48, blue:0.15, alpha:1))
        let cancel  = PixelBtn(title: "✕ 取消", bg: NSColor(red:0.5, green:0.12, blue:0.12, alpha:1))

        reset.frame   = NSRect(x: bx,              y: by, width: btnW, height: btnH)
        confirm.frame = NSRect(x: bx+btnW+gap,     y: by, width: btnW, height: btnH)
        cancel.frame  = NSRect(x: bx+(btnW+gap)*2, y: by, width: btnW, height: btnH)

        reset.onClick   = { [weak self] in self?.resetSize() }
        confirm.onClick = { [weak self] in self?.dismiss(confirm: true) }
        cancel.onClick  = { [weak self] in self?.dismiss(confirm: false) }

        [reset, confirm, cancel].forEach { cv.addSubview($0) }
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let h = CGFloat(sender.doubleValue)
        applyHeight(h)
        sizeLabel.stringValue = "\(Int(h)) px"
    }

    private func applyHeight(_ h: CGFloat) {
        guard let win = petWindow else { return }
        let clamped = max(minH, min(maxH, h))
        let w = clamped * ratio
        win.setFrame(CGRect(x: startCX - w/2, y: startCY - clamped/2,
                           width: w, height: clamped),
                    display: true, animate: false)
    }

    private func resetSize() {
        let defaultH: CGFloat = 149
        slider.doubleValue = Double(defaultH)
        applyHeight(defaultH)
        sizeLabel.stringValue = "\(Int(defaultH)) px"
    }

    func dismiss(confirm: Bool) {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if !confirm {
            // 取消：还原
            applyHeight(startH)
        } else {
            // 确认：把新中心记下来（下次 resize 从这里开始）
            if let win = petWindow {
                startCX = win.frame.midX
                startCY = win.frame.midY
            }
        }
        petVC?.startAnimation(for: petVC?.currentState ?? .idle)
        orderOut(nil)
        if ResizeHUD.current === self { ResizeHUD.current = nil }
    }

    // Esc 关闭（取消）
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { dismiss(confirm: false) }
        else { super.keyDown(with: event) }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
    }
}

// MARK: - 像素风背景

class PixelBgView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // 深色半透明底
        NSColor(red:0.08, green:0.06, blue:0.02, alpha:0.92).setFill(); b.fill()
        // 外层深棕边框
        NSColor(red:0.65, green:0.42, blue:0.08, alpha:1).setStroke()
        NSBezierPath(rect: b.insetBy(dx:0.5, dy:0.5)).lineWidth = 2
        NSBezierPath(rect: b.insetBy(dx:0.5, dy:0.5)).stroke()
        // 内层亮高光（左上）
        NSColor(red:1, green:0.88, blue:0.4, alpha:0.35).setStroke()
        let hl = NSBezierPath()
        hl.move(to: NSPoint(x:3, y:b.height-3))
        hl.line(to: NSPoint(x:3, y:3))
        hl.line(to: NSPoint(x:b.width-3, y:3))
        hl.lineWidth = 1; hl.stroke()
    }
}
