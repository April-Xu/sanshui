import AppKit

class PetWindowController: NSWindowController {

    convenience init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let petH: CGFloat = 149
        let petW: CGFloat = petH * (192.0 / 208.0)
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
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.isMovableByWindowBackground = false
        window.hasShadow = false

        self.init(window: window)

        let vc = PetViewController()
        window.contentViewController = vc
    }
}
