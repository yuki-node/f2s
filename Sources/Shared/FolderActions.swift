import AppKit

enum FolderActions {
    static func openShell(in directory: URL, completion: @escaping (Error?) -> Void) {
        let terminal = terminalApplication(for: directory)
        NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: .init()) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    static func copyPath(of directory: URL) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()
        return board.setString(directory.path, forType: .string)
    }

    private static func terminalApplication(for directory: URL) -> URL {
        let systemTerminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app", isDirectory: true)
        // iTerm2's “Make Default Term” registers the Shell role for Unix executables.
        if let terminal = registeredTerminal(type: "public.unix-executable", role: .shell, directory: directory) {
            return terminal
        }
        return registeredTerminal(type: "com.apple.terminal.shell-script", role: .all, directory: directory) ?? systemTerminal
    }

    private static func registeredTerminal(type: String, role: LSRolesMask, directory: URL) -> URL? {
        guard let handler = LSCopyDefaultRoleHandlerForContentType(type as CFString, role)?.takeRetainedValue(),
              let candidate = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handler as String),
              let documents = Bundle(url: candidate)?.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]],
              documents.contains(where: { $0["CFBundleTypeRole"] as? String == "Shell" }) else {
            return nil
        }
        var acceptsDirectory = DarwinBoolean(false)
        let result = LSCanURLAcceptURL(directory as CFURL, candidate as CFURL, .all, .acceptDefault, &acceptsDirectory)
        return result == noErr && acceptsDirectory.boolValue ? candidate : nil
    }
}
