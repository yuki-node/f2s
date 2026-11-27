import AppKit
import FinderSync

@objc(F2SFinderMenu)
final class FinderMenu: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override var toolbarItemName: String { "f2s" }
    override var toolbarItemToolTip: String { "打开 Shell 或复制当前文件夹路径" }
    override var toolbarItemImage: NSImage {
        let image = Bundle(for: Self.self).image(forResource: "AppIcon") ?? NSImage(named: NSImage.folderName)!
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .toolbarItemMenu else { return nil }
        let folder = FIFinderSyncController.default().targetedURL()
        let menu = NSMenu()
        menu.autoenablesItems = false
        let open = menu.addItem(withTitle: "Open Shell", action: #selector(openShell(_:)), keyEquivalent: "")
        let copy = menu.addItem(withTitle: "Copy Path", action: #selector(copyPath(_:)), keyEquivalent: "")
        for item in [open, copy] {
            item.target = self
            item.representedObject = folder
            item.isEnabled = folder?.isFileURL == true
        }
        return menu
    }

    @objc private func openShell(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? URL ?? FIFinderSyncController.default().targetedURL() else { return }
        FolderActions.openShell(in: folder) { error in
            if let error { NSAlert(error: error).runModal() }
        }
    }

    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? URL ?? FIFinderSyncController.default().targetedURL() else { return }
        if !FolderActions.copyPath(of: folder) { NSSound.beep() }
    }
}
