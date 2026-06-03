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

    // 普通拖拽
    private var mouseDownPos: CGPoint = .zero
    private var lastDragDirection: Int = 0
    private let dragThreshold: CGFloat = 5

    // Resize 模式
    private let minH: CGFloat = 16
    private let maxH: CGFloat = 88
    private let aspectRatio: CGFloat = 192.0 / 208.0
    private let defaultH: CGFloat = 56
    private let screenMargin: CGFloat = 16
    private let handleZone: CGFloat = 10   // 边缘几px内算 handle

    private(set) var isResizeMode = false
    private var isResizeDragging = false
    private var resizeStartMouse: CGPoint = .zero   // 屏幕坐标
    private var resizeStartH: CGFloat = 0
    private var resizeStartOrigin: CGPoint = .zero  // 窗口左下角（屏幕坐标）
    private var resizeHandleDir: CGPoint = .zero    // 拖拽方向向量（±1）
    private var handleOverlay: HandleOverlayView?
    private var controlBar: ResizeControlBar? = nil
    private var frameBeforeResize: NSRect = .zero
    private var globalMouseMonitor: Any?

    // resize mode 下整个视图都是拖拽区，不需要精确 hit 判断

    // MARK: - Resize 模式开关

    func enterResizeMode() {
        guard let win = self.window else { return }
        isResizeMode = true
        win.isMovable = false
        frameBeforeResize = win.frame
        petVC?.animationTimer?.invalidate()
        showHandles()

        let bar = ResizeControlBar.makeBar()
        positionControlBar(bar, relativeTo: win)
        bar.onConfirm = { [weak self] in self?.confirmResize() }
        bar.onCancel  = { [weak self] in self?.cancelResize() }
        bar.onReset   = { [weak self] in self?.resetResize() }
        win.addChildWindow(bar, ordered: .above)
        controlBar = bar
        win.makeFirstResponder(self)   // ← Esc 需要成为 first responder
        win.makeKeyAndOrderFront(nil)

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.confirmResize()
        }
    }

    func confirmResize() {
        guard isResizeMode else { return }
        isResizeMode = false
        window?.isMovable = true
        hideHandles()
        detachControlBar()
        removeGlobalMonitor()
        petVC?.startAnimation(for: petVC?.currentState ?? .idle)
        NSCursor.arrow.set()
    }

    func cancelResize() {
        guard isResizeMode else { return }
        isResizeMode = false
        window?.isMovable = true
        hideHandles()
        detachControlBar()
        removeGlobalMonitor()
        window?.setFrame(frameBeforeResize, display: true, animate: false)
        petVC?.startAnimation(for: petVC?.currentState ?? .idle)
        NSCursor.arrow.set()
    }

    func resetResize() {
        guard let win = self.window else { return }
        let h = defaultH, w = h * aspectRatio
        // 底部左角锚定，只改尺寸
        let f = CGRect(x: win.frame.origin.x, y: win.frame.origin.y, width: w, height: h)
        win.setFrame(f, display: true, animate: false)
        refreshHandlesAndBar()
    }

    private func removeGlobalMonitor() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
    }

    private func detachControlBar() {
        if let bar = controlBar {
            window?.removeChildWindow(bar)
            bar.orderOut(nil)
            controlBar = nil
        }
    }

    private func positionControlBar(_ bar: ResizeControlBar, relativeTo win: NSWindow) {
        guard let screen = NSScreen.main?.visibleFrame else {
            bar.position(below: win); return
        }
        var origin = NSPoint(x: win.frame.midX - bar.frame.width/2,
                            y: win.frame.minY - bar.frame.height - 6)
        // 如果下方没有空间就放上面
        if origin.y < screen.minY {
            origin.y = win.frame.maxY + 6
        }
        origin.x = max(screen.minX, min(screen.maxX - bar.frame.width, origin.x))
        bar.setFrameOrigin(origin)
    }

    private func refreshHandlesAndBar() {
        guard let win = self.window else { return }
        handleOverlay?.frame = bounds
        handleOverlay?.needsDisplay = true
        if let bar = controlBar { positionControlBar(bar, relativeTo: win) }
    }

    // MARK: - Handle 绘制

    private func showHandles() {
        hideHandles()
        let ov = HandleOverlayView(frame: bounds)
        ov.wantsLayer = true
        ov.layer?.backgroundColor = NSColor.clear.cgColor
        // 不需要在 handleOverlay 处理事件，全部由 PetContainerView 负责
        addSubview(ov)
        handleOverlay = ov
    }

    private func hideHandles() {
        handleOverlay?.removeFromSuperview()
        handleOverlay = nil
    }

    // MARK: - 右键菜单 & 键盘

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 && isResizeMode { // Esc
            cancelResize()
        } else {
            super.keyDown(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let label = isResizeMode ? "完成调整大小" : "调整大小"
        let resizeItem = NSMenuItem(title: label, action: #selector(toggleResize), keyEquivalent: "")
        resizeItem.target = self
        menu.addItem(resizeItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 Sanshui", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func toggleResize() { isResizeMode ? confirmResize() : enterResizeMode() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - 鼠标事件（全部在 PetContainerView 处理，HandleOverlay 不拦截）

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with event: NSEvent) {
        if isResizeMode {
            // resize mode：整个视图都是 resize 区，直接开始
            isResizeDragging = true
            resizeStartMouse = NSEvent.mouseLocation
            resizeStartH      = window?.frame.height ?? defaultH
            resizeStartOrigin = window?.frame.origin ?? .zero
            NSCursor.crosshair.set()
            return
        }
        mouseDownPos = NSEvent.mouseLocation
        lastDragDirection = 0
    }

    override func mouseDragged(with event: NSEvent) {
        if isResizeMode && isResizeDragging {
            guard let win = self.window else { return }
            let cur = NSEvent.mouseLocation
            let dx = cur.x - resizeStartMouse.x
            let dy = cur.y - resizeStartMouse.y
            // 对角线位移：右/上 = 放大，左/下 = 缩小
            let delta = (dx - dy) / sqrt(2)

            let newH = max(minH, min(maxH, resizeStartH + delta))
            let newW = newH * aspectRatio

            // 中心锚定：resize 不改变宠物视觉中心位置
            let cx = resizeStartOrigin.x + (resizeStartH * aspectRatio) / 2
            let cy = resizeStartOrigin.y + resizeStartH / 2
            let newOriginX = cx - newW / 2
            let newOriginY = cy - newH / 2

            win.setFrame(CGRect(x: newOriginX, y: newOriginY, width: newW, height: newH),
                        display: true, animate: false)
            refreshHandlesAndBar()
            return
        }

        guard !isResizeMode else { return }
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
        if isResizeMode {
            isResizeDragging = false
            return
        }
        guard let petVC else { return }
        petVC.isDragging ? petVC.handleDragEnded() : petVC.handleClick()
    }

    // 普通拖拽边界约束
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
