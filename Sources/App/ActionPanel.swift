import AppKit

final class ActionPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
