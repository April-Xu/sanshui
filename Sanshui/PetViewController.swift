import AppKit

class PetViewController: NSViewController {
    private var imageView: SpriteImageView!
    private var spriteParser: SpriteSheetParser?
    var animationTimer: Timer?
    private var currentFrames: [NSImage] = []
    private var currentFrameIndex = 0
    private(set) var currentState: PetState = .idle
    var isManualState = false

    // 拖拽
    var isDragging = false
    private var dragOffset = CGPoint.zero

    override func loadView() {
        // frame 先用 0，窗口创建后 contentView 会被 window 自动 resize
        let v = PetContainerView(frame: NSRect(x: 0, y: 0, width: 137, height: 149))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        v.autoresizingMask = [.width, .height]
        v.petVC = self
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupSpriteSheet()
        startAnimation(for: .idle)

        QoderStateMonitor.shared.onStateChange = { [weak self] newState in
            DispatchQueue.main.async {
                self?.transitionToState(newState)
                // Streaming 浮层：coding 时显示，其他时候隐藏
                if let win = self?.view.window {
                    if newState == .coding {
                        StreamingOverlayPanel.show(petWindow: win)
                    } else {
                        StreamingOverlayPanel.hide()
                    }
                }
            }
        }
        QoderStateMonitor.shared.onLiveTokenUpdate = { delta in
            DispatchQueue.main.async {
                StreamingOverlayPanel.current?.updateTokens(delta)
            }
        }
        QoderStateMonitor.shared.onCompletionTokens = { [weak self] tokens in
            DispatchQueue.main.async {
                guard let win = self?.view.window else { return }
                TokenBubblePanel.show(tokens: tokens, petWindow: win)
            }
        }
        QoderStateMonitor.shared.startMonitoring()
        // 随机漫步已移除
    }

    // MARK: - ImageView

    private func setupImageView() {
        imageView = SpriteImageView(frame: view.bounds)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        imageView.imageAlignment = .alignBottom
        imageView.autoresizingMask = [.width, .height]
        view.addSubview(imageView)

    }

    private func setupSpriteSheet() {
        // 精灵图: 2304×2288 = 12列×11行，192×208/格
        spriteParser = SpriteSheetParser(imageName: "spritesheet", columns: 12, rows: 11)
    }

    // MARK: - 动画

    func startAnimation(for state: PetState) {
        animationTimer?.invalidate()
        currentFrameIndex = 0
        let config = state.animationConfig
        currentFrames = spriteParser?.frames(row: config.row, count: config.frameCount) ?? []
        guard !currentFrames.isEmpty else { return }
        imageView.image = currentFrames[0]
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / config.fps, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    // 用指定行直接播，不改 currentState（拖拽方向用）
    private func playRow(_ row: Int, frameCount: Int, fps: Double) {
        animationTimer?.invalidate()
        currentFrameIndex = 0
        currentFrames = spriteParser?.frames(row: row, count: frameCount) ?? []
        guard !currentFrames.isEmpty else { return }
        imageView.image = currentFrames[0]
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        guard !currentFrames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % currentFrames.count
        imageView.image = currentFrames[currentFrameIndex]
        imageView.needsDisplay = true
    }

    // MARK: - 状态管理

    func transitionToState(_ state: PetState) {
        guard !isManualState, !isDragging else { return }
        applyState(state)
    }

    private func applyState(_ state: PetState) {
        guard state != currentState else { return }
        currentState = state
        startAnimation(for: state)
        // coding 状态（坐着用电脑）姿势更大，缩小 0.82 倍视觉上统一
        let scale: CGFloat = (state == .coding) ? 0.82 : 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            imageView.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    // MARK: - 点击 → 弹跳效果（不切帧，避免 spritesheet 尺寸不一致导致缩小）
    // 等新 spritesheet 尺寸统一后可换回 waving 行

    func handleClick() {
        guard !isDragging else { return }
        let options: [PetState] = [.waving, .sunburn, .sunburnSwim]
        let pick = options.randomElement() ?? .waving
        playOnce(state: pick) { }
    }

    // MARK: - 拖拽 → 根据方向播 running-left / running-right

    func handleDragBegan(direction: Int) {
        isDragging = true
        guard let window = view.window else { return }
        let mouse = NSEvent.mouseLocation
        dragOffset = CGPoint(
            x: mouse.x - window.frame.origin.x,
            y: mouse.y - window.frame.origin.y
        )
        // direction > 0 = 向右 → row 1 (running-right)
        // direction < 0 = 向左 → row 2 (running-left)
        let row = direction >= 0 ? 1 : 2
        playRow(row, frameCount: 8, fps: 10)
    }

    func handleDragDirectionChanged(_ direction: Int) {
        let row = direction >= 0 ? 1 : 2
        playRow(row, frameCount: 8, fps: 10)
    }

    func handleDragMoved() {
        guard isDragging, let window = view.window else { return }
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(
            x: mouse.x - dragOffset.x,
            y: mouse.y - dragOffset.y
        ))
        // 边界约束：任意一边至少留 16pt 在屏幕内
        (view as? PetContainerView)?.clampWindowToScreen()
    }

    func handleDragEnded() {
        isDragging = false
        startAnimation(for: currentState)
    }

    /// 单次播放，播完后回到 previousState 并回调
    func playOnce(state: PetState, then completion: @escaping () -> Void) {
        let config = state.animationConfig
        let duration = Double(config.frameCount) / config.fps
        isManualState = true
        startAnimation(for: state)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isManualState = false
            self?.startAnimation(for: self?.currentState ?? .idle)
            completion()
        }
    }

}

final class SpriteImageView: NSImageView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        super.draw(dirtyRect)
    }
}

// MARK: - 鼠标事件容器

class PetContainerView: NSView {
    weak var petVC: PetViewController?

    private var mouseDownPos: CGPoint = .zero
    private var lastDragDirection: Int = 0
    private let dragThreshold: CGFloat = 5
    private let screenMargin: CGFloat = 16
    private var didReceiveMouseDown = false   // 防止假 mouseDragged 触发 running 动画

    // MARK: - 右键菜单

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let resizeItem = NSMenuItem(title: "调整大小", action: #selector(showResizeSlider), keyEquivalent: "")
        resizeItem.target = self
        menu.addItem(resizeItem)

        let updateItem = NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let delegate = NSApp.delegate as? AppDelegate
        let launchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = delegate?.isLoginItemEnabled() == true ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Sanshui", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func checkForUpdates() {
        (NSApp.delegate as? AppDelegate)?.checkForUpdates()
    }

    @objc private func showResizeSlider() {
        guard let win = self.window, let vc = petVC else { return }
        ResizeHUD.show(petWindow: win, petVC: vc)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.toggleLaunchAtLogin(sender)
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        didReceiveMouseDown = true
        mouseDownPos = NSEvent.mouseLocation
        lastDragDirection = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard didReceiveMouseDown, let petVC else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - mouseDownPos.x
        if !petVC.isDragging {
            let dy = cur.y - mouseDownPos.y
            if sqrt(dx*dx + dy*dy) > dragThreshold {
                let dir = dx >= 0 ? 1 : -1
                lastDragDirection = dir
                petVC.handleDragBegan(direction: dir)
            }
        } else {
            let newDir = dx >= 0 ? 1 : -1
            if newDir != lastDragDirection {
                lastDragDirection = newDir
                petVC.handleDragDirectionChanged(newDir)
            }
            petVC.handleDragMoved()
        }
    }

    override func mouseUp(with event: NSEvent) {
        didReceiveMouseDown = false
        guard let petVC else { return }
        petVC.isDragging ? petVC.handleDragEnded() : petVC.handleClick()
    }

    func clampWindowToScreen() {
        guard let window = self.window else { return }
        var f = window.frame

        // 找宠物当前所在的显示器（用窗口中心点匹配）
        let center = CGPoint(x: f.midX, y: f.midY)
        let targetScreen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.min(by: { a, b in
                // 没有精确命中时取距离最近的屏幕
                let da = hypot(a.frame.midX - center.x, a.frame.midY - center.y)
                let db = hypot(b.frame.midX - center.x, b.frame.midY - center.y)
                return da < db
            })

        guard let screen = targetScreen?.visibleFrame else { return }

        // 每边至少留 screenMargin 像素在屏幕内，允许跨越其他显示器
        // （不限制到单屏：只要宠物没完全飞出所有屏幕组成的联合区域就行）
        let allScreensUnion = NSScreen.screens.reduce(CGRect.null) { $0.union($1.visibleFrame) }

        f.origin.x = max(allScreensUnion.minX - f.width + screenMargin,
                         min(allScreensUnion.maxX - screenMargin, f.origin.x))
        f.origin.y = max(allScreensUnion.minY - f.height + screenMargin,
                         min(allScreensUnion.maxY - screenMargin, f.origin.y))

        // 额外保证：在当前目标屏幕内至少有一边可见（防止卡在两屏夹缝中消失）
        let visibleInTarget = f.intersection(screen)
        if visibleInTarget.width < screenMargin && visibleInTarget.height < screenMargin {
            // 完全不在目标屏内，拉回到最近边
            f.origin.x = max(screen.minX - f.width + screenMargin,
                             min(screen.maxX - screenMargin, f.origin.x))
            f.origin.y = max(screen.minY - f.height + screenMargin,
                             min(screen.maxY - screenMargin, f.origin.y))
        }

        if f.origin != window.frame.origin { window.setFrameOrigin(f.origin) }
    }
}

// MARK: - 非模态尺寸调整面板

class SizePanel: NSPanel {
    private static var current: SizePanel?

    private weak var petWindow: NSWindow?
    private var startH: CGFloat = 0
    private var startCX: CGFloat = 0
    private var startCY: CGFloat = 0
    private let ratio: CGFloat = 192.0 / 208.0

    static func show(for petWindow: NSWindow) {
        current?.orderOut(nil)
        current = nil
        let p = SizePanel(petWindow: petWindow)
        current = p
        p.makeKeyAndOrderFront(nil)
    }

    init(petWindow: NSWindow) {
        self.petWindow = petWindow
        self.startH  = petWindow.frame.height
        self.startCX = petWindow.frame.midX
        self.startCY = petWindow.frame.midY

        let w: CGFloat = 220, h: CGFloat = 72
        // 面板放在宠物正上方
        let px = petWindow.frame.midX - w/2
        let py = petWindow.frame.maxY + 8
        super.init(contentRect: NSRect(x: px, y: py, width: w, height: h),
                   styleMask: [.titled, .closable, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.title = "调整大小"
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isMovableByWindowBackground = true
        buildUI()
    }

    private func buildUI() {
        guard let cv = contentView else { return }

        let slider = NSSlider(frame: NSRect(x: 12, y: 36, width: 196, height: 20))
        slider.minValue = 16; slider.maxValue = 200
        slider.doubleValue = Double(startH)
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        cv.addSubview(slider)

        let label = NSTextField(labelWithString: "\(Int(startH)) px")
        label.frame = NSRect(x: 80, y: 14, width: 60, height: 16)
        label.alignment = .center
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.tag = 1
        cv.addSubview(label)

        let ok = NSButton(title: "确定", target: self, action: #selector(confirm))
        ok.frame = NSRect(x: 120, y: 10, width: 42, height: 20)
        ok.bezelStyle = .rounded
        cv.addSubview(ok)

        let cancel = NSButton(title: "取消", target: self, action: #selector(revert))
        cancel.frame = NSRect(x: 166, y: 10, width: 42, height: 20)
        cancel.bezelStyle = .rounded
        cv.addSubview(cancel)
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        guard let win = petWindow else { return }
        let h = CGFloat(sender.doubleValue)
        let w = h * ratio
        let newRect = CGRect(x: startCX - w/2, y: startCY - h/2, width: w, height: h)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        win.setFrame(newRect, display: false, animate: false)
        // 强制 contentView 立刻同步到新尺寸并 layout
        win.contentView?.setFrameSize(NSSize(width: w, height: h))
        win.contentView?.needsLayout = true
        win.contentView?.layoutSubtreeIfNeeded()
        win.displayIfNeeded()
        CATransaction.commit()
        (contentView?.viewWithTag(1) as? NSTextField)?.stringValue = "\(Int(h)) px"
    }

    @objc private func confirm() { SizePanel.current = nil; orderOut(nil) }

    @objc private func revert() {
        let w = startH * ratio
        petWindow?.setFrame(CGRect(x: startCX-w/2, y: startCY-startH/2, width: w, height: startH),
                           display: true, animate: false)
        SizePanel.current = nil; orderOut(nil)
    }
}
