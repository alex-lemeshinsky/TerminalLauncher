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
            cwd: FileManager.default.currentDirectoryPath,
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
