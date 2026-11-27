import AppKit
import FinderSync

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var panel: ActionPanel?
    private var directory: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // URL launches are handled by application(_:open:); only direct launches show the panel.
        if notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == false { return }
        if !FIFinderSyncController.isExtensionEnabled {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "启用 f2s 的 Finder 扩展"
            if #available(macOS 15, *) {
                alert.informativeText = "点「启用 f2s」即可使用工具栏菜单。也可以在系统设置的「登录项与扩展 → 访达」中手动管理。"
            } else {
                alert.informativeText = "点「启用 f2s」即可使用工具栏菜单。也可以在系统的扩展设置中手动管理。"
            }
            alert.addButton(withTitle: "启用 f2s")
            alert.addButton(withTitle: "取消")
            alert.addButton(withTitle: "在系统设置中管理…")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                do {
                    FinderToolbar.prepareToShowExtension(ExtensionElection.identifier)
                    try ExtensionElection.setEnabled(true)
                } catch {
                    finishWithAlert("无法启用 f2s", detail: error.localizedDescription)
                    return
                }
            case .alertThirdButtonReturn:
                openExtensionSettings()
                return
            default: break
            }
            NSApp.terminate(nil)
            return
        }
        let point = NSEvent.mouseLocation
        do {
            directory = try FinderDirectory.current()
            showActions(at: point)
        } catch {
            finishWithAlert("无法获取 Finder 目录", detail: error.localizedDescription)
        }
    }

    private func openExtensionSettings() {
        if #available(macOS 15, *) {
            let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open(url, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    if error != nil {
                        self.finishWithAlert("无法打开扩展设置", detail: "请打开「系统设置 → 通用 → 登录项与扩展」，在「访达」中管理 f2s。")
                    } else {
                        NSApp.terminate(nil)
                    }
                }
            }
        } else {
            FIFinderSyncController.showExtensionManagementInterface()
            NSApp.terminate(nil)
        }
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
            directory = current
            switch action {
            case .openShell: openShell()
            case .newFile: newFile()
            }
        } catch {
            finishWithAlert("无法获取 Finder 目录", detail: error.localizedDescription)
        }
    }

    private func showActions(at point: NSPoint) {
        let actions = [("Open Shell", "terminal", #selector(openShell)),
                       ("Copy Path", "doc.on.doc", #selector(copyPath)),
                       ("New File…", "doc.badge.plus", #selector(newFile)),
                       ("Quit f2s", "power", #selector(quitF2S))]
        let size = NSSize(width: 152, height: CGFloat(actions.count * 30 + 8))
        let panel = ActionPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless], backing: .buffered, defer: false)
        panel.title = "f2s"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 9
        background.layer?.masksToBounds = true
        panel.contentView = background
        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.0, target: self, action: action.2)
            button.frame = NSRect(x: 6, y: size.height - 33 - CGFloat(index * 30), width: 140, height: 28)
            button.image = NSImage(systemSymbolName: action.1, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.alignment = .left
            button.bezelStyle = .recessed
            button.showsBorderOnlyWhileMouseInside = true
            background.addSubview(button)
        }
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        if let bounds = screen?.visibleFrame {
            let x = min(max(point.x, bounds.minX), bounds.maxX - size.width)
            let y = min(max(point.y - size.height - 4, bounds.minY), bounds.maxY - size.height)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func windowDidResignKey(_ notification: Notification) {
        if panel != nil { NSApp.terminate(nil) }
    }

    @objc private func openShell() {
        guard let directory else { return }
        panel?.delegate = nil
        panel?.orderOut(nil)
        FolderActions.openShell(in: directory) { error in
            if let error {
                self.finishWithAlert("无法打开终端", detail: error.localizedDescription)
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    @objc private func copyPath() {
        guard let directory else { return }
        panel?.delegate = nil
        panel?.orderOut(nil)
        if FolderActions.copyPath(of: directory) {
            NSApp.terminate(nil)
        } else {
            finishWithAlert("无法复制路径", detail: "写入剪贴板失败，请重试。")
        }
    }

    @objc private func newFile() {
        guard let directory else { return }
        panel?.delegate = nil
        panel?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let file = NewFilePanel(directory: directory).run() {
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }
        NSApp.terminate(nil)
    }

    @objc private func quitF2S() {
        QuitLauncher.launch(from: Bundle.main.bundleURL)
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
