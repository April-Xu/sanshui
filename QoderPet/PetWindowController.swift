import AppKit

class PetWindowController: NSWindowController {
    var petViewController: PetViewController?

    convenience init() {
        // 放到屏幕右下角，Dock 上方
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // 精灵格子比例 192:208 ≈ 0.923，窗口按此比例设置
        let petW: CGFloat = 52
        let petH: CGFloat = 56
        // Dock 右侧上方，稍微离 Dock 远一点
        let initX = screenFrame.maxX - petW - 200
        let initY = screenFrame.minY + 160

        let window = NSWindow(
            contentRect: NSRect(x: initX, y: initY, width: petW, height: petH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating          // 悬浮在所有窗口之上
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false  // 我们自己处理拖拽
        window.hasShadow = false

        self.init(window: window)

        let vc = PetViewController()
        petViewController = vc
        window.contentViewController = vc
    }
}
