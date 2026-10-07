import Foundation
import PathStore

/// Asks the running TerminalLauncher.app to refresh the widget. Returns `false` when the app can't be reached.
public protocol WidgetReloader: Sendable {
    func requestReload() async -> Bool
}

public struct CommandResult: Equatable, Sendable {
    public var stdout: [String]
    public var stderr: [String]
    public var exitCode: Int32

    public init(stdout: [String] = [], stderr: [String] = [], exitCode: Int32 = 0) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// The logic behind `tl add`, `tl rm` and `tl ls`. Everything outside the process
/// (store location, reload, file system checks, clock) is injected so it can be tested.
public struct Commands: Sendable {
    private static let reloadFailedMessage =
        "Saved, but couldn't reach TerminalLauncher.app; the widget will update within 30 minutes."

    private let makeStore: @Sendable () throws(PathStoreError) -> PathStore
    private let reloader: any WidgetReloader
    private let folderStatus: @Sendable (String) -> FolderStatus
    private let cwd: String
    private let home: String
    private let now: @Sendable () -> Date

    public init(
        makeStore: @escaping @Sendable () throws(PathStoreError) -> PathStore,
        reloader: any WidgetReloader,
        folderStatus: @escaping @Sendable (String) -> FolderStatus,
        cwd: String,
        home: String,
        now: @escaping @Sendable () -> Date
    ) {
        self.makeStore = makeStore
        self.reloader = reloader
        self.folderStatus = folderStatus
        self.cwd = cwd
        self.home = home
        self.now = now
    }

    public func add(_ raw: String) async -> CommandResult {
        let path = PathCanonicalizer.canonicalize(raw, cwd: cwd, home: home)
        let shown = PathDisplay.abbreviated(path, home: home)
        switch folderStatus(path) {
        case .folder: break
        case .missing: return failure("\(shown) does not exist")
        case .notFolder: return failure("\(shown) is not a folder")
        }

        let updated: (items: [SavedPath], alreadyPresent: Bool)
        do {
            let store = try makeStore()
            updated = try store.load().addingToTop(path, at: now())
            try store.save(updated.items)
        } catch {
            return failure(error.message)
        }

        var result = CommandResult(stdout: [
            updated.alreadyPresent ? "\(shown) already saved, moved to top" : "Added \(shown)",
        ])
        let hidden = WidgetLayout.rows(for: updated.items, capacity: WidgetLayout.maxRows).moreCount
        if hidden > 0 {
            result.stdout.append("Note: the widget shows up to \(WidgetLayout.maxRows) folders; \(hidden) are hidden.")
        }
        await reload(into: &result)
        return result
    }

    public func remove(_ target: String) async -> CommandResult {
        let removed: SavedPath
        do {
            let store = try makeStore()
            let items = try store.load()
            let outcome: (items: [SavedPath], removed: SavedPath)
            if !target.isEmpty, target.utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) }) {
                // A digit string too large for Int is out of range like any other bad number.
                guard let found = Int(target).flatMap({ items.removing(number: $0) }) else {
                    return failure("no item number \(target) (the list has \(items.count))")
                }
                outcome = found
            } else {
                let path = PathCanonicalizer.canonicalize(target, cwd: cwd, home: home)
                guard let found = items.removing(path: path) else {
                    return failure("\(PathDisplay.abbreviated(path, home: home)) is not in the list")
                }
                outcome = found
            }
            try store.save(outcome.items)
            removed = outcome.removed
        } catch {
            return failure(error.message)
        }

        var result = CommandResult(stdout: ["Removed \(PathDisplay.abbreviated(removed.path, home: home))"])
        await reload(into: &result)
        return result
    }

    public func list() -> CommandResult {
        let items: [SavedPath]
        do {
            items = try makeStore().load()
        } catch {
            return failure(error.message)
        }
        if items.isEmpty {
            return CommandResult(stdout: ["No folders yet. Run \"tl .\" in a folder."])
        }
        let lines = items.enumerated().map { index, item in
            let row = String(format: "%2d  %@", index + 1, PathDisplay.abbreviated(item.path, home: home))
            return folderStatus(item.path) == .folder ? row : row + "   (missing)"
        }
        return CommandResult(stdout: lines)
    }

    private func failure(_ message: String) -> CommandResult {
        CommandResult(stderr: ["Error: \(message)"], exitCode: 1)
    }

    private func reload(into result: inout CommandResult) async {
        if await !reloader.requestReload() {
            result.stderr.append(Self.reloadFailedMessage)
        }
    }
}
