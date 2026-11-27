import AppKit
import FinderSync

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder menu requests arrive via application(_:open:).
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == false { return }
        if FIFinderSyncController.isExtensionEnabled {
            finishWithAlert("f2s 已启用", detail: "点击 Finder 工具栏中的 f2s 图标即可使用。")
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "启用 f2s 的 Finder 扩展"
        alert.informativeText = "在 Finder 工具栏中打开终端、复制路径或新建文件。"
        alert.addButton(withTitle: "启用 f2s")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                FinderToolbar.prepareToShowExtension(ExtensionElection.identifier)
                try ExtensionElection.setEnabled(true)
            } catch {
                finishWithAlert("无法启用 f2s", detail: error.localizedDescription)
                return
            }
        }
        NSApp.terminate(nil)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let request = urls.first else { return }
        do {
            let current = try FinderDirectory.current()
            // Launch Services URLs can also arrive from other apps. Only operate on the
            // real Finder directory, and only if it is still the one from the original click.
            guard let action = FinderRequest.matching(request, currentDirectory: current) else {
                finishWithAlert("Finder 目录已更改", detail: "请在目标 Finder 窗口中重新选择操作。")
                return
            }
            switch action {
            case .openShell:
                FolderActions.openShell(in: current) { error in
                    if let error {
                        self.finishWithAlert("无法打开终端", detail: error.localizedDescription)
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            case .newFile:
                NSApp.activate(ignoringOtherApps: true)
                if let file = NewFilePanel(directory: current).run() {
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                }
                NSApp.terminate(nil)
            }
        } catch {
            finishWithAlert("无法获取 Finder 目录", detail: error.localizedDescription)
        }
    }

    private func finishWithAlert(_ title: String, detail: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        alert.runModal()
        NSApp.terminate(nil)
    }
}
