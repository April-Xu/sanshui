import AppKit
import Foundation

// MARK: - 轻量自动更新（下载 DMG → 挂载 → 替换 app → 重启）

struct UpdateChecker {

    private static let jsonURL = "https://raw.githubusercontent.com/April-Xu/sanshui/codex/sanshui-codex-pet/update.json"

    /// silent=true：只有有新版才弹窗；false：无论如何给反馈
    static func check(silent: Bool) {
        guard let url = URL(string: jsonURL) else { return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("Sanshui-UpdateChecker/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latestVersion = json["version"] as? String,
                      let downloadURL  = json["url"] as? String
                else {
                    if !silent { showError("无法连接到更新服务器，请稍后再试。") }
                    return
                }

                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                let notes   = json["notes"] as? String ?? ""

                if isNewer(latestVersion, than: current) {
                    promptUpdate(version: latestVersion, notes: notes, url: downloadURL)
                } else if !silent {
                    let a = NSAlert()
                    a.messageText = "已是最新版本"
                    a.informativeText = "当前版本 \(current) 已是最新。"
                    a.addButton(withTitle: "好")
                    a.runModal()
                }
            }
        }.resume()
    }

    // MARK: - 弹更新确认

    private static func promptUpdate(version: String, notes: String, url: String) {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let a = NSAlert()
        a.messageText = "发现新版本 \(version)"
        a.informativeText = "当前：\(current)\n\n\(notes)"
        a.addButton(withTitle: "立即更新")
        a.addButton(withTitle: "稍后再说")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        downloadAndInstall(url: url, version: version)
    }

    // MARK: - 下载 → 挂载 → 替换 → 重启

    private static func downloadAndInstall(url: String, version: String) {
        showProgress("正在下载 \(version)…")

        guard let src = URL(string: url) else { return }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Sanshui-update.dmg")

        URLSession.shared.downloadTask(with: src) { localURL, _, error in
            guard let localURL else {
                DispatchQueue.main.async { showError("下载失败：\(error?.localizedDescription ?? "未知错误")") }
                return
            }
            try? FileManager.default.removeItem(at: tmp)
            try? FileManager.default.moveItem(at: localURL, to: tmp)
            DispatchQueue.main.async { mountAndReplace(dmg: tmp) }
        }.resume()
    }

    private static func mountAndReplace(dmg: URL) {
        showProgress("正在安装…")

        // 挂载 DMG（-nobrowse 不在 Finder 显示，-noverify 跳过校验加速）
        let mount = Process()
        mount.launchPath = "/usr/bin/hdiutil"
        mount.arguments  = ["attach", dmg.path, "-nobrowse", "-noverify", "-readonly"]
        let pipe = Pipe()
        mount.standardOutput = pipe
        mount.standardError  = Pipe()
        do { try mount.run() } catch { showError("挂载失败"); return }
        mount.waitUntilExit()

        // 从输出中找挂载点
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let mountLine = output.components(separatedBy: "\n").first(where: { $0.contains("/Volumes/") }),
              let mountPoint = mountLine.components(separatedBy: "\t").last?.trimmingCharacters(in: .whitespaces)
        else { showError("找不到挂载点"); return }

        // 找 .app
        guard let appName = (try? FileManager.default.contentsOfDirectory(atPath: mountPoint))?
                .first(where: { $0.hasSuffix(".app") })
        else { showError("DMG 内找不到 .app"); return }

        let srcApp = "\(mountPoint)/\(appName)"
        // 安装到 ~/Applications 或 /Applications（用原路径）
        guard let destApp = Bundle.main.bundlePath as String? else { return }

        // 复制替换（用 shell cp -r 覆盖）
        let cp = Process()
        cp.launchPath = "/bin/sh"
        cp.arguments  = ["-c", "cp -rf '\(srcApp)' '\(destApp)'"]
        cp.standardError = Pipe()
        do { try cp.run() } catch { showError("复制失败"); return }
        cp.waitUntilExit()

        // 卸载 DMG
        let detach = Process()
        detach.launchPath = "/usr/bin/hdiutil"
        detach.arguments = ["detach", mountPoint, "-quiet"]
        try? detach.run()

        // 清理临时文件
        try? FileManager.default.removeItem(at: dmg)

        // 提示重启
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = "更新完成！"
            a.informativeText = "新版本已安装，点击重启生效。"
            a.addButton(withTitle: "立即重启")
            a.addButton(withTitle: "稍后手动重启")
            if a.runModal() == .alertFirstButtonReturn { relaunch() }
        }
    }

    // MARK: - 重启 app

    private static func relaunch() {
        guard let appPath = Bundle.main.bundlePath as String? else { return }
        // 用 open 重新打开，延迟让当前进程先退出
        let script = "sleep 1 && open '\(appPath)'"
        let p = Process()
        p.launchPath = "/bin/sh"
        p.arguments = ["-c", script]
        try? p.run()
        NSApp.terminate(nil)
    }

    // MARK: - 工具

    private static func showProgress(_ msg: String) {
        DispatchQueue.main.async {
            let a = NSAlert()
            a.messageText = msg
            a.addButton(withTitle: "后台进行中…")
            // 不 runModal，只是显示一下状态（非阻塞）
            _ = a  // 这里只是占位，实际用 toast 或 print 代替
            print("[Update] \(msg)")
        }
    }

    private static func showError(_ msg: String) {
        let a = NSAlert()
        a.messageText = "更新失败"
        a.informativeText = msg
        a.alertStyle = .warning
        a.addButton(withTitle: "好")
        a.runModal()
    }

    private static func isNewer(_ latest: String, than current: String) -> Bool {
        let lv = latest.split(separator: ".").compactMap { Int($0) }
        let cv = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(lv.count, cv.count) {
            let l = i < lv.count ? lv[i] : 0
            let c = i < cv.count ? cv[i] : 0
            if l != c { return l > c }
        }
        return false
    }
}
