import Foundation

enum ExtensionElection {
    static let identifier = "local.finder-to-iterm.FinderMenu"

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            // A drag-installed app has no installer script to register the extension.
            let menu = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/FinderMenu.appex")
            try runPluginKit(["-a", menu.path])
        }
        try runPluginKit(["-e", enabled ? "use" : "ignore", "-i", identifier])
    }

    private static func runPluginKit(_ arguments: [String]) throws {
        let tool = Process()
        tool.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        tool.arguments = arguments
        try tool.run()
        tool.waitUntilExit()
        if tool.terminationStatus != 0 {
            throw NSError(domain: "f2s", code: Int(tool.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "macOS 无法更改 f2s 的 Finder 扩展状态。"
            ])
        }
    }
}
