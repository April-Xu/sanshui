import AppKit

// 太阳按钮已移除——点击宠物触发随机动画（waving/sunburn/sunburnSwim）
// SunButton 保留类定义以防其他文件引用

class PetControlBar: NSPanel {
    weak var petVC: PetViewController?

    static func make(petVC: PetViewController) -> PetControlBar {
        let bar = PetControlBar(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        bar.isOpaque = false
        bar.backgroundColor = .clear
        bar.petVC = petVC
        return bar
    }

    func positionRight(of petWindow: NSWindow) {}
}
