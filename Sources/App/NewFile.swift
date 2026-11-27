import Foundation

enum NewFile {
    static func create(named name: String, in directory: URL) throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.utf8.contains(0) else {
            throw NameError.invalid
        }
        let file = directory.appendingPathComponent(name, isDirectory: false)
        do {
            try Data().write(to: file, options: .withoutOverwriting)
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
            throw NameError.exists
        }
        return file
    }

    private enum NameError: LocalizedError {
        case invalid, exists

        var errorDescription: String? {
            switch self {
            case .invalid: return "Enter a file name in this folder. Names cannot be . or .. or contain a slash."
            case .exists: return "This name is already in use. Choose another name."
            }
        }
    }
}
