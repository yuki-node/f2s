import AppKit

enum FinderDirectory {
    static func current() throws -> URL {
        guard let scriptURL = Bundle.main.url(forResource: "finder-directory", withExtension: "scpt") else {
            throw FinderError.script("应用缺少读取 Finder 目录所需的文件。")
        }

        var failure: NSDictionary?
        guard let script = NSAppleScript(contentsOf: scriptURL, error: &failure) else {
            throw FinderError.script(failure?[NSAppleScript.errorMessage] as? String ?? "无法加载 Finder 脚本。")
        }

        let result = script.executeAndReturnError(&failure)
        if let failure {
            switch failure[NSAppleScript.errorNumber] as? Int {
            case 1000:
                throw FinderError.noWindow
            case 1001, -1728, -1700:
                throw FinderError.noFolder
            case -1743:
                throw FinderError.permissionDenied
            default:
                throw FinderError.script(failure[NSAppleScript.errorMessage] as? String ?? "Finder 读取失败。")
            }
        }

        guard let location = result.stringValue, let directory = URL(string: location), directory.isFileURL else {
            throw FinderError.noFolder
        }
        return directory
    }
}

enum FinderError: LocalizedError {
    case noWindow
    case noFolder
    case permissionDenied
    case script(String)

    var errorDescription: String? {
        switch self {
        case .noWindow:
            return "请先打开一个 Finder 文件夹窗口。"
        case .noFolder:
            return "请在 Finder 中打开一个实际的文件夹，再点击按钮。"
        case .permissionDenied:
            return "请在「系统设置 → 隐私与安全性 → 自动化」中允许 f2s 访问 Finder，然后重试。"
        case .script(let message):
            return message
        }
    }
}
