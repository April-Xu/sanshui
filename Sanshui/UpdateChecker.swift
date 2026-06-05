import AppKit
import Foundation

// MARK: - 轻量更新检查（不依赖 Sparkle，无需代码签名）
// 拉 GitHub 上的 update.json，比较版本号，弹对话框引导下载

struct UpdateChecker {

    private static let jsonURL = "https://raw.githubusercontent.com/April-Xu/sanshui/codex/sanshui-codex-pet/update.json"

    /// silent=true：只有有新版本才弹窗；silent=false：无论如何都给反馈
    static func check(silent: Bool) {
        guard let url = URL(string: jsonURL) else { return }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("Sanshui-UpdateChecker/1.0", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latestVersion = json["version"] as? String,
                      let downloadURL = json["url"] as? String
                else {
                    if !silent {
                        showAlert(title: "检查更新失败", message: "无法连接到更新服务器，请稍后再试。", downloadURL: nil)
                    }
                    return
                }

                let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                let releaseNotes = json["notes"] as? String ?? ""

                if isNewer(latestVersion, than: current) {
                    showAlert(
                        title: "发现新版本 \(latestVersion)",
                        message: "当前版本：\(current)\n\n\(releaseNotes)",
                        downloadURL: downloadURL
                    )
                } else if !silent {
                    showAlert(title: "已是最新版本", message: "当前版本 \(current) 已是最新。", downloadURL: nil)
                }
            }
        }.resume()
    }

    private static func showAlert(title: String, message: String, downloadURL: String?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational

        if let url = downloadURL {
            alert.addButton(withTitle: "下载更新")
            alert.addButton(withTitle: "稍后再说")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: url)!)
            }
        } else {
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    /// 语义版本比较：latestVersion > currentVersion
    private static func isNewer(_ latest: String, than current: String) -> Bool {
        let lv = latest.split(separator: ".").compactMap { Int($0) }
        let cv = current.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(lv.count, cv.count)
        for i in 0..<maxLen {
            let l = i < lv.count ? lv[i] : 0
            let c = i < cv.count ? cv[i] : 0
            if l != c { return l > c }
        }
        return false
    }
}
