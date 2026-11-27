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
            alert.informativeText = "在扩展设置中打开 f2s，即可从 Finder 工具栏展开菜单。"
            alert.addButton(withTitle: "打开扩展设置")
            alert.addButton(withTitle: "取消")
            if alert.runModal() == .alertFirstButtonReturn {
                FIFinderSyncController.showExtensionManagementInterface()
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

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let request = urls.first else { return }
        do {
            let current = try FinderDirectory.current()
            // Launch Services URLs can also arrive from other apps. Only operate on the
            // real Finder directory, and only if it is still the one from the original click.
            guard ShellRequest.matches(request, currentDirectory: current) else {
                finishWithAlert("无法打开终端", detail: "请在目标 Finder 窗口中重新选择 Open Shell。")
                return
            }
            directory = current
            openShell()
        } catch {
            finishWithAlert("无法获取 Finder 目录", detail: error.localizedDescription)
        }
    }

    private func showActions(at point: NSPoint) {
        let size = NSSize(width: 152, height: 68)
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
        let actions = [("Open Shell", "terminal", #selector(openShell)), ("Copy Path", "doc.on.doc", #selector(copyPath))]
        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.0, target: self, action: action.2)
            button.frame = NSRect(x: 6, y: 35 - index * 30, width: 140, height: 28)
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
