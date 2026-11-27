import AppKit
import Darwin

// Finder may keep more than one extension instance (for example, in Open dialogs).
// Match the installed executables, including for XPC processes absent from NSWorkspace.
func runningProcesses(at paths: Set<String>) throws -> [pid_t] {
    var pids = [pid_t](repeating: 0, count: 256)
    while true {
        let capacity = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let bytes = proc_listpids(UInt32(PROC_UID_ONLY), getuid(), &pids, capacity)
        guard bytes > 0 else { throw POSIXError(.EIO) }
        if bytes < capacity {
            var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
            return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.stride).filter { pid in
                pid > 0 && proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0
                    && paths.contains(String(cString: buffer))
            }
        }
        pids += [pid_t](repeating: 0, count: pids.count)
    }
}

do {
    let contents = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    let host = Bundle(url: contents.deletingLastPathComponent())
    let menu = Bundle(url: contents.appendingPathComponent("PlugIns/FinderMenu.appex"))
    guard let hostURL = host?.executableURL, let menuURL = menu?.executableURL else {
        throw CocoaError(.fileNoSuchFile)
    }
    try ExtensionElection.setEnabled(false)
    let executables: Set = [hostURL.resolvingSymlinksInPath().path, menuURL.resolvingSymlinksInPath().path]
    let deadline = ProcessInfo.processInfo.systemUptime + 5
    while true {
        let pids = try runningProcesses(at: executables)
        if pids.isEmpty { break }
        guard ProcessInfo.processInfo.systemUptime < deadline else {
            throw NSError(domain: "f2s", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "f2s 仍在退出。请稍后再将它移到废纸篓。"
            ])
        }
        for pid in pids {
            if kill(pid, SIGTERM) != 0 && errno != ESRCH {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
} catch {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "无法退出 f2s"
    alert.informativeText = error.localizedDescription
    alert.runModal()
    exit(EXIT_FAILURE)
}
