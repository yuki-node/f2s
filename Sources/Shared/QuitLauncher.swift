import AppKit
import OSLog

enum QuitLauncher {
    static func launch(from host: URL) {
        let helper = host.appendingPathComponent("Contents/Helpers/Quit.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: helper, configuration: configuration) { _, error in
            if let error {
                Logger(subsystem: "local.finder-to-iterm", category: "Quit")
                    .error("Could not launch Quit: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { NSSound.beep() }
            }
        }
    }
}
