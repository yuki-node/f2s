import AppKit

@main
struct F2SApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--install-toolbar" {
            do {
                if try FinderToolbar.removeLegacyButtons(appURL: Bundle.main.bundleURL) {
                    try FinderToolbar.reload()
                }
            } catch {
                FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
                exit(EXIT_FAILURE)
            }
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
