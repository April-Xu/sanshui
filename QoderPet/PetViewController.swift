import AppKit

class PetViewController: NSViewController {
    private var imageView: NSImageView!
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
        let v = PetContainerView(frame: NSRect(x: 0, y: 0, width: 52, height: 56))
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        v.petVC = self
        // 开启 mouseMoved 追踪（resize mode 用）
        v.addTrackingArea(NSTrackingArea(
            rect: v.bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: v, userInfo: nil))
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupSpriteSheet()
        startAnimation(for: .idle)

        QoderStateMonitor.shared.onStateChange = { [weak self] newState in
            DispatchQueue.main.async { self?.transitionToState(newState) }
        }
        QoderStateMonitor.shared.startMonitoring()
        // 随机漫步已移除
    }

    // MARK: - ImageView

    private func setupImageView() {
        imageView = NSImageView(frame: view.bounds)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        imageView.imageAlignment = .alignBottom
        view.addSubview(imageView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupSpriteSheet() {
        spriteParser = SpriteSheetParser(imageName: "spritesheet", columns: 8, rows: 10)
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
    }

    // MARK: - 状态管理

    func transitionToState(_ state: PetState) {
        guard !isManualState, !isDragging else { return }
        applyState(state)
    }

    func setStateManually(_ state: PetState) {
        isManualState = true
        QoderStateMonitor.shared.forceState(state)
        applyState(state)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isManualState = false
        }
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
        let prev = currentState
        isManualState = true
        startAnimation(for: .waving)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isManualState = false
            self?.startAnimation(for: prev)
        }
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

// MARK: - 鼠标事件容器

class PetContainerView: NSView {
    weak var petVC: PetViewController?

    private var mouseDownPos: CGPoint = .zero
    private var lastDragDirection: Int = 0
    private let dragThreshold: CGFloat = 5
    private let screenMargin: CGFloat = 16

    // MARK: - 右键菜单

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let resizeItem = NSMenuItem(title: "调整大小", action: #selector(showResizeSlider), keyEquivalent: "")
        resizeItem.target = self
        menu.addItem(resizeItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Sanshui", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func showResizeSlider() {
        guard let win = self.window else { return }
        let startH  = win.frame.height
        let startCX = win.frame.midX
        let startCY = win.frame.midY

        // 用 helper 做 target/action（KVO 在 modal run loop 里不稳定）
        let helper = SliderHelper(window: win)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 50))

        let slider = NSSlider(frame: NSRect(x: 8, y: 26, width: 224, height: 20))
        slider.minValue = 16; slider.maxValue = 200
        slider.doubleValue = Double(startH)
        slider.isContinuous = true
        slider.target = helper
        slider.action = #selector(SliderHelper.sliderMoved(_:))

        let label = NSTextField(labelWithString: "\(Int(startH)) px")
        label.frame = NSRect(x: 90, y: 4, width: 60, height: 18)
        label.alignment = .center
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        helper.label = label

        container.addSubview(slider)
        container.addSubview(label)

        let alert = NSAlert()
        alert.messageText = "调整大小"
        alert.informativeText = "拖动滑块实时预览（16 – 200 px）"
        alert.accessoryView = container
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        _ = helper  // 保持引用到 runModal 结束

        if response != .alertFirstButtonReturn {
            let w = startH * (192.0/208.0)
            win.setFrame(CGRect(x: startCX-w/2, y: startCY-startH/2, width: w, height: startH),
                        display: true, animate: false)
        }
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        mouseDownPos = NSEvent.mouseLocation
        lastDragDirection = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard let petVC else { return }
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
        guard let petVC else { return }
        petVC.isDragging ? petVC.handleDragEnded() : petVC.handleClick()
    }

    func clampWindowToScreen() {
        guard let window = self.window, let screen = NSScreen.main?.visibleFrame else { return }
        var f = window.frame
        f.origin.x = max(screen.minX - f.width + screenMargin,
                    min(screen.maxX - screenMargin, f.origin.x))
        f.origin.y = max(screen.minY - f.height + screenMargin,
                    min(screen.maxY - screenMargin, f.origin.y))
        if f.origin != window.frame.origin { window.setFrameOrigin(f.origin) }
    }
}

// MARK: - 滑块 Helper

private class SliderHelper: NSObject {
    weak var window: NSWindow?
    weak var label: NSTextField?
    private let ratio: CGFloat = 192.0 / 208.0
    private var lastCX: CGFloat = 0
    private var lastCY: CGFloat = 0

    init(window: NSWindow) {
        self.window = window
        self.lastCX = window.frame.midX
        self.lastCY = window.frame.midY
    }

    @objc func sliderMoved(_ sender: NSSlider) {
        guard let win = window else { return }
        let h = CGFloat(sender.doubleValue)
        let w = h * ratio
        // 用初始中心锚定，避免每次都从新 midX/midY 算（会累积偏移）
        win.setFrame(CGRect(x: lastCX - w/2, y: lastCY - h/2, width: w, height: h),
                    display: true, animate: false)
        label?.stringValue = "\(Int(h)) px"
    }
}
