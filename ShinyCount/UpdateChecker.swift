import Foundation
import AppKit

class UpdateChecker {
    static let currentVersion = "0.8"
    static let versionURL = "https://raw.githubusercontent.com/Diegoboss005/ShinyCount/main/latest_version.txt"
    static let releasesURL = "https://github.com/Diegoboss005/ShinyCount/releases/latest"

    static func checkForUpdates(silent: Bool = true) {
        guard let url = URL(string: versionURL) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let latest = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) else { return }

            let hasUpdate = compareVersions(currentVersion, latest) < 0

            DispatchQueue.main.async {
                if hasUpdate {
                    showUpdateAlert(latestVersion: latest)
                } else if !silent {
                    showUpToDateAlert()
                }
            }
        }.resume()
    }

    private static func compareVersions(_ v1: String, _ v2: String) -> Int {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(parts1.count, parts2.count)
        for i in 0..<maxLen {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 < p2 { return -1 }
            if p1 > p2 { return  1 }
        }
        return 0
    }

    private static func showUpdateAlert(latestVersion: String) {
        let alert = NSAlert()
        alert.messageText = "Nueva versión disponible"
        alert.informativeText = "ShinyCount \(latestVersion) ya está disponible. Tienes la versión \(currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Descargar")
        alert.addButton(withTitle: "Más tarde")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: releasesURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private static func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "ShinyCount está actualizado"
        alert.informativeText = "Tienes la versión más reciente (\(currentVersion))."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
