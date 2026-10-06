import AppKit
import Foundation
import PathStore

/// Asks the running TerminalLauncher.app to refresh the widget by opening `tlaunch://reload` without activating it.
public struct WorkspaceReloader: WidgetReloader {
    public init() {}

    public func requestReload() async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.open(LaunchURL.reload, configuration: configuration)
            return true
        } catch {
            return false
        }
    }
}

extension Commands {
    public static func live() -> Commands {
        Commands(
            makeStore: { () throws(PathStoreError) -> PathStore in try PathStore.appGroup() },
            reloader: WorkspaceReloader(),
            folderStatus: { FolderStatus.of($0) },
            cwd: logicalCwd(
                pwd: ProcessInfo.processInfo.environment["PWD"],
                physical: FileManager.default.currentDirectoryPath,
                sameFile: sameFileOnDisk),
            home: PathDisplay.realHome,
            now: { Date() }
        )
    }
}

extension CommandResult {
    /// Writes stdout lines to standard output and stderr lines to standard error.
    public func emit() {
        for line in stdout { print(line) }
        for line in stderr {
            FileHandle.standardError.write(Data((line + "\n").utf8))
        }
    }
}

/// The current directory the way the shell shows it (POSIX `pwd -L`): `$PWD` when it is an absolute path
/// without `.` or `..` components that names the same directory as `physical`, else `physical`.
/// `FileManager.currentDirectoryPath` is getcwd(), which resolves symlinks.
public func logicalCwd(pwd: String?, physical: String, sameFile: (String, String) -> Bool) -> String {
    guard let pwd, pwd.hasPrefix("/") else { return physical }
    let components = pwd.split(separator: "/", omittingEmptySubsequences: true)
    guard !components.contains(".") && !components.contains("..") else { return physical }
    return sameFile(pwd, physical) ? pwd : physical
}

/// True when both paths exist and, after following symlinks, are the same file (same device and inode).
public func sameFileOnDisk(_ a: String, _ b: String) -> Bool {
    var first = stat()
    var second = stat()
    guard stat(a, &first) == 0, stat(b, &second) == 0 else { return false }
    return first.st_dev == second.st_dev && first.st_ino == second.st_ino
}
