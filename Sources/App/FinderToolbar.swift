import AppKit

enum FinderToolbar {
    static let bundleIdentifier = "com.apple.finder"
    static let configurationKey = "NSToolbar Configuration Browser"

    private static let itemsKey = "TB Item Identifiers"
    private static let itemPlistsKey = "TB Item Plists"
    private static let fileItem = "com.apple.finder.loc "
    private static let urlKey = "_CFURLString"

    static func prepareToShowExtension(_ identifier: String) {
        let finder = bundleIdentifier as CFString
        // Finder removes the toolbar item on disable but remembers auto-adding it.
        // On explicit enable, let Finder place it again using its own current layout.
        let historyKey = "FXSyncExtensionToolbarItemsAutomaticallyAdded" as CFString
        guard CFPreferencesAppSynchronize(finder),
              !CFPreferencesAppValueIsForced(historyKey, finder),
              !CFPreferencesAppValueIsForced(configurationKey as CFString, finder),
              let history = CFPreferencesCopyAppValue(historyKey, finder) as? [String],
              history.contains(identifier) else { return }
        let layout = CFPreferencesCopyAppValue(configurationKey as CFString, finder) as? [String: Any]
        if let items = layout?[itemsKey] as? [String], items.contains(identifier) { return }
        CFPreferencesSetAppValue(historyKey, history.filter { $0 != identifier } as CFArray, finder)
        CFPreferencesAppSynchronize(finder)
    }

    static func removeLegacyButtons(appURL: URL) throws -> Bool {
        let domain = bundleIdentifier as CFString
        let key = configurationKey as CFString
        guard CFPreferencesAppSynchronize(domain), !CFPreferencesAppValueIsForced(key, domain) else {
            throw ConfigurationError.unavailable
        }

        let stored = CFPreferencesCopyAppValue(key, domain)
        guard stored == nil || stored is [String: Any] else {
            throw ConfigurationError.invalid
        }
        let original = stored as? [String: Any] ?? [:]
        let updated = try removingLegacyButtons(for: appURL, from: original)
        guard !(original as NSDictionary).isEqual(to: updated) else { return false }

        CFPreferencesSetAppValue(key, updated as CFDictionary, domain)
        guard CFPreferencesAppSynchronize(domain) else { throw ConfigurationError.unavailable }
        return true
    }

    static func removingLegacyButtons(for appURL: URL, from original: [String: Any]) throws -> [String: Any] {
        guard original[itemsKey] == nil || original[itemsKey] is [String],
              original[itemPlistsKey] == nil || original[itemPlistsKey] is [String: Any] else {
            throw ConfigurationError.invalid
        }

        var configuration = original
        let items = original[itemsKey] as? [String] ?? []
        let itemPlists = original[itemPlistsKey] as? [String: Any] ?? [:]

        let installedPath = appURL.standardizedFileURL.path
        let previousPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/f2s.app").standardizedFileURL.path
        let appSlots = items.indices.filter { index in
            guard items[index] == fileItem, let item = itemPlists[String(index)] as? [String: Any],
                  let path = destination(of: item)?.standardizedFileURL.path else { return false }
            return path == installedPath || path == previousPath
        }
        guard !appSlots.isEmpty else { return original }

        guard itemPlists.keys.allSatisfy({ key in Int(key).map(items.indices.contains) == true }) else {
            throw ConfigurationError.invalid
        }
        var updatedItems: [String] = []
        var updatedPlists: [String: Any] = [:]
        for index in items.indices where !appSlots.contains(index) {
            updatedPlists[String(updatedItems.count)] = itemPlists[String(index)]
            updatedItems.append(items[index])
        }
        configuration[itemsKey] = updatedItems
        configuration[itemPlistsKey] = updatedPlists
        return configuration
    }

    private static func destination(of item: [String: Any]) -> URL? {
        // Finder rewrites the path to a file-reference URL and stores an alias on reload.
        if let urlString = item[urlKey] as? String, let url = URL(string: urlString),
           url.isFileURL, let pathURL = CFURLCreateFilePathURL(nil, url as CFURL, nil) {
            return pathURL.takeRetainedValue() as URL
        }

        guard let alias = item["_CFURLAliasData"] as? Data,
              let bookmark = CFURLCreateBookmarkDataFromAliasRecord(nil, alias as CFData) else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark.takeRetainedValue() as Data, options: [.withoutUI, .withoutMounting],
                        relativeTo: nil, bookmarkDataIsStale: &isStale)
    }

    static func reload() throws {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return
        }
        guard finder.terminate() else { throw ConfigurationError.relaunch }

        let deadline = Date().addingTimeInterval(5)
        while !finder.isTerminated && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        guard finder.isTerminated else { throw ConfigurationError.relaunch }

        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launch.arguments = ["-g", "-a", finderURL.path]
        try launch.run()
        launch.waitUntilExit()
        guard launch.terminationStatus == 0 else { throw ConfigurationError.relaunch }
    }

    enum ConfigurationError: LocalizedError {
        case unavailable, invalid, relaunch

        var errorDescription: String? {
            switch self {
            case .unavailable: return "无法保存当前账户的 Finder 工具栏设置。"
            case .invalid: return "Finder 工具栏设置的格式无法识别。"
            case .relaunch: return "Finder 工具栏已配置。请在 Finder 退出后重新打开 Finder，或退出并重新登录 macOS。"
            }
        }
    }
}
