import Foundation

enum ShellRequest {
    private static let scheme = "f2s-finder"
    private static let action = "open-shell"

    static func url(for directory: URL) -> URL? {
        guard directory.isFileURL else { return nil }
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = action
        parts.path = directory.standardizedFileURL.path
        return parts.url
    }

    static func matches(_ request: URL, currentDirectory: URL) -> Bool {
        guard let expected = url(for: currentDirectory) else { return false }
        return request == expected
    }
}
