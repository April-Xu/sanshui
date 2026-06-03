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
        spriteParser = SpriteSheetParser(imageName: "spritesheet", columns: 8, rows: 9)
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
}

// MARK: - 鼠标事件容器

class PetContainerView: NSView {
    weak var petVC: PetViewController?

    // 移动拖拽
    private var mouseDownPos: CGPoint = .zero
    private var lastDragDirection: Int = 0
    private let dragThreshold: CGFloat = 5

    // Resize 模式
    private let minH: CGFloat = 16
    private let maxH: CGFloat = 88
    private let aspectRatio: CGFloat = 192.0 / 208.0
    private let screenMargin: CGFloat = 16

    private(set) var isResizeMode = false
    private var resizingHandle: Int = -1
    private var resizeStartMouse: CGPoint = .zero
    private var resizeStartFrame: NSRect = .zero
    private var handleOverlay: HandleOverlayView?
    private var controlBar: ResizeControlBar? = nil
    private var frameBeforeResize: NSRect = .zero
    private let defaultH: CGFloat = 56

    // handle 归一化位置（与 HandleOverlayView.positions 一致）
    private let handlePositions: [(CGFloat, CGFloat)] = [
        (0, 0), (0.5, 0), (1, 0),
        (0, 0.5),          (1, 0.5),
        (0, 1), (0.5, 1), (1, 1),
    ]

    // MARK: - Resize 模式开关

    func enterResizeMode() {
        guard let win = self.window else { return }
        isResizeMode = true
        frameBeforeResize = win.frame
        petVC?.animationTimer?.invalidate()
        showHandles()

        // 控制栏
        let bar = ResizeControlBar.makeBar()
        bar.position(below: win)
        bar.onConfirm = { [weak self] in self?.confirmResize() }
        bar.onCancel  = { [weak self] in self?.cancelResize() }
        bar.onReset   = { [weak self] in self?.resetResize() }
        win.addChildWindow(bar, ordered: .above)
        controlBar = bar
        bar.makeKeyAndOrderFront(nil)
        win.makeKeyAndOrderFront(nil)
    }

    func confirmResize() {
        isResizeMode = false
        hideHandles()
        detachControlBar()
        petVC?.startAnimation(for: petVC?.currentState ?? .idle)
        NSCursor.arrow.set()
    }

    func cancelResize() {
        isResizeMode = false
        hideHandles()
        detachControlBar()
        // 还原到进入 resize 前的 frame
        window?.setFrame(frameBeforeResize, display: true, animate: false)
        petVC?.startAnimation(for: petVC?.currentState ?? .idle)
        NSCursor.arrow.set()
    }

    func resetResize() {
        guard let win = self.window else { return }
        let h = defaultH
        let w = h * aspectRatio
        var f = win.frame
        let cx = f.midX
        f.size = NSSize(width: w, height: h)
        f.origin.x = cx - w / 2
        win.setFrame(f, display: true, animate: false)
        showHandles()
        controlBar?.position(below: win)
    }

    private func detachControlBar() {
        if let bar = controlBar {
            window?.removeChildWindow(bar)
            bar.orderOut(nil)
            controlBar = nil
        }
    }

    // MARK: - Handle 覆盖层（NSView，坐标系和事件完全一致）

    private func showHandles() {
        hideHandles()
        let ov = HandleOverlayView(frame: bounds)
        ov.wantsLayer = true
        ov.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(ov)
        handleOverlay = ov
    }

    private func hideHandles() {
        handleOverlay?.removeFromSuperview()
        handleOverlay = nil
    }

    private func hitHandle(_ loc: NSPoint) -> Int {
        return handleOverlay?.hitHandle(loc) ?? -1
    }

    // MARK: - 右键菜单

    override func keyDown(with event: NSEvent) {
        // Esc (keyCode 53)
        if event.keyCode == 53 && isResizeMode {
            confirmResize()
            return
        }
        super.keyDown(with: event)
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

    @objc private func toggleResize() {
        isResizeMode ? confirmResize() : enterResizeMode()
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }

    // MARK: - 鼠标事件

    override func mouseDown(with event: NSEvent) {
        let loc = event.locationInWindow
        if isResizeMode {
            let h = hitHandle(loc)
            if h >= 0 {
                resizingHandle = h
                resizeStartMouse = NSEvent.mouseLocation
                resizeStartFrame = window?.frame ?? .zero
            }
            return
        }
        mouseDownPos = NSEvent.mouseLocation
        lastDragDirection = 0
    }

    override func mouseMoved(with event: NSEvent) {
        guard isResizeMode else { return }
        let h = hitHandle(event.locationInWindow)
        if h >= 0 {
            // 四向箭头光标（用系统私有方式获取）
            if let img = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil) {
                NSCursor(image: img, hotSpot: NSPoint(x: 8, y: 8)).set()
            } else {
                NSCursor.crosshair.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isResizeMode && resizingHandle >= 0 {
            guard let window = self.window else { return }
            let cur = NSEvent.mouseLocation
            let dx = cur.x - resizeStartMouse.x
            let dy = cur.y - resizeStartMouse.y

            // 根据 handle 位置计算缩放方向
            let (nx, ny) = handlePositions[resizingHandle]
            var delta: CGFloat = 0
            if abs(dx) > abs(dy) {
                // 主要拖拽方向是水平：左侧向左拖增大，右侧向右拖增大
                delta = nx < 0.5 ? -dx : dx
            } else {
                // 主要拖拽方向是竖直：下侧向下拖增大，上侧向上拖增大
                delta = ny < 0.5 ? -dy : dy
            }

            let newH = max(minH, min(maxH, resizeStartFrame.height + delta))
            let newW = newH * aspectRatio

            // 中心点锚定（不随拖拽移动）
            let centerX = resizeStartFrame.midX
            let centerY = resizeStartFrame.midY
            var newFrame = CGRect(
                x: centerX - newW/2,
                y: centerY - newH/2,
                width: newW,
                height: newH
            )

            // 约束：任意一边至少留 screenMargin 在屏幕内
            if let screen = NSScreen.main?.visibleFrame {
                // 左右约束
                if newFrame.minX < screen.minX {
                    newFrame.origin.x = screen.minX
                }
                if newFrame.maxX > screen.maxX {
                    newFrame.origin.x = screen.maxX - newW
                }
                // 上下约束
                if newFrame.minY < screen.minY {
                    newFrame.origin.y = screen.minY
                }
                if newFrame.maxY > screen.maxY {
                    newFrame.origin.y = screen.maxY - newH
                }
            }

            window.setFrame(newFrame, display: true, animate: false)
            handleOverlay?.frame = bounds
            handleOverlay?.needsDisplay = true

            // 控制栏位置，带边界检查
            if let bar = controlBar {
                bar.position(below: window)
                // 确保控制栏也不掉出屏幕
                if let screen = NSScreen.main?.visibleFrame {
                    var barFrame = bar.frame
                    if barFrame.minX < screen.minX {
                        barFrame.origin.x = screen.minX
                    }
                    if barFrame.maxX > screen.maxX {
                        barFrame.origin.x = screen.maxX - barFrame.width
                    }
                    if barFrame.minY < screen.minY {
                        barFrame.origin.y = screen.minY + 50  // 往上挪点
                    }
                    bar.setFrame(barFrame, display: false)
                }
            }
            return
        }

        guard let petVC, !isResizeMode else { return }
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
            resizingHandle = -1
            return
        }
        guard let petVC else { return }
        if petVC.isDragging {
            petVC.handleDragEnded()
        } else {
            petVC.handleClick()
        }
    }

    // 普通拖拽时也加边界约束
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
