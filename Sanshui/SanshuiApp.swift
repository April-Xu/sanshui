import SwiftUI
import AppKit
import ServiceManagement

@main
struct QoderPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindowController: PetWindowController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        petWindowController = PetWindowController()
        petWindowController?.showWindow(nil)

        DispatchQueue.main.async { self.setupStatusBar() }

        // 注册登录时自动启动
        registerLoginItem()
    }

    // MARK: - 状态栏

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let btn = statusItem?.button {
            // 用系统符号图标，兼容性好，不容易被菜单栏遮住
            if let img = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "QoderPet") {
                img.isTemplate = true   // 自动适配深色/浅色模式
                btn.image = img
            } else {
                btn.title = "🐾"
            }
        }

        let menu = NSMenu()

        // 显示/隐藏
        menu.addItem(withTitle: "显示 / 隐藏 Sanshui", action: #selector(togglePet), keyEquivalent: "")
            .target = self


        menu.addItem(.separator())

        // 开机自启开关
        let launchItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLoginItemEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
    }

    @objc func togglePet() {
        guard let w = petWindowController?.window else { return }
        w.isVisible ? w.orderOut(nil) : w.makeKeyAndOrderFront(nil)
    }

    @objc func forceState(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let state = PetState(rawValue: raw) else { return }
        petWindowController?.petViewController?.setStateManually(state)
    }

    // MARK: - 登录自启

    func registerLoginItem() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        } else {
            // macOS 12 及以下：写 LaunchAgent plist
            installLaunchAgent()
        }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                try? SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try? SMAppService.mainApp.register()
                sender.state = .on
            }
        }
    }

    func isLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    // macOS 12 fallback
    private func installLaunchAgent() {
        guard let appPath = Bundle.main.bundlePath as String? else { return }
        let plist: [String: Any] = [
            "Label": "com.sanshui.app",
            "ProgramArguments": ["\(appPath)/Contents/MacOS/QoderPet"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let dir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = "\(dir)/com.sanshui.app.plist"
        (plist as NSDictionary).write(toFile: path, atomically: true)
    }
}
