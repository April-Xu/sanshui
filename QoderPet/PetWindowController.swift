import AppKit

class PetWindowController: NSWindowController {
    var petViewController: PetViewController?
    var controlBar: PetControlBar?

    convenience init() {
        // 放到屏幕右下角，Dock 上方
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // 精灵格子比例 192:208 ≈ 0.923，窗口按此比例设置
        let petH: CGFloat = 149
        let petW: CGFloat = petH * (192.0 / 208.0)
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

        // 持久控制栏（太阳按钮等），放宠物右侧
        DispatchQueue.main.async { [weak self] in
            guard let self, let vc = self.petViewController else { return }
            let bar = PetControlBar.make(petVC: vc)
            bar.positionRight(of: window)
            window.addChildWindow(bar, ordered: .above)
            self.controlBar = bar

            // 监听窗口 resize，保持控制栏贴在右侧
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window, queue: .main) { [weak bar, weak window] _ in
                guard let bar = bar, let w = window else { return }
                bar.positionRight(of: w)
            }
        }
    }
}
