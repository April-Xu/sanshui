import SwiftUI
import AppKit
import ServiceManagement

@main
struct SanshuiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindowController: PetWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        petWindowController = PetWindowController()
        petWindowController?.showWindow(nil)

        registerLoginItem()

        // 启动后后台静默检查一次更新
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            UpdateChecker.check(silent: true)
        }
    }

    // MARK: - 更新

    func checkForUpdates() {
        DispatchQueue.global().async {
            UpdateChecker.check(silent: false)
        }
    }

    // MARK: - 登录自启

    func registerLoginItem() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        } else {
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

    private func installLaunchAgent() {
        guard let appPath = Bundle.main.bundlePath as String? else { return }
        let plist: [String: Any] = [
            "Label": "com.sanshui.app",
            "ProgramArguments": ["\(appPath)/Contents/MacOS/Sanshui"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let dir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = "\(dir)/com.sanshui.app.plist"
        (plist as NSDictionary).write(toFile: path, atomically: true)
    }
}
