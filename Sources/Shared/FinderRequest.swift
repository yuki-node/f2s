import Foundation

enum FinderRequest: String, CaseIterable {
    case openShell = "open-shell"
    case newFile = "new-file"

    private static let scheme = "f2s-finder"

    func url(for directory: URL) -> URL? {
        guard directory.isFileURL else { return nil }
        var parts = URLComponents()
        parts.scheme = Self.scheme
        parts.host = rawValue
        parts.path = directory.standardizedFileURL.path
        return parts.url
    }

    static func matching(_ request: URL, currentDirectory: URL) -> Self? {
        allCases.first { $0.url(for: currentDirectory) == request }
    }
}
