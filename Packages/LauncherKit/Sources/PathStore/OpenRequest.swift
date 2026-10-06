import Foundation

public protocol TerminalOpener: Sendable {
    func openTerminal(at folder: URL) async throws
}

public enum OpenOutcome: Equatable, Sendable {
    case opened
    case notInList
    case folderMissing(path: String)
    case listUnreadable(message: String)
    case failed(message: String)

    /// The alert to show the user, or `nil` when the click should be silent.
    public func alertMessage(home: String) -> String? {
        switch self {
        case .opened, .notInList, .listUnreadable:
            return nil
        case let .folderMissing(path):
            let shown = PathDisplay.abbreviated(path, home: home)
            let quoted = "'" + shown.replacingOccurrences(of: "'", with: "'\\''") + "'"
            return "\(shown) no longer exists. Remove it with tl rm \(quoted)."
        case let .failed(message):
            return "Couldn't open Terminal: \(message)"
        }
    }
}

public struct OpenRequestHandler: Sendable {
    private let makeStore: @Sendable () throws(PathStoreError) -> PathStore
    private let folderStatus: @Sendable (String) -> FolderStatus
    private let opener: any TerminalOpener

    public init(
        makeStore: @escaping @Sendable () throws(PathStoreError) -> PathStore,
        folderStatus: @escaping @Sendable (String) -> FolderStatus,
        opener: any TerminalOpener
    ) {
        self.makeStore = makeStore
        self.folderStatus = folderStatus
        self.opener = opener
    }

    /// Opens Terminal at `path` only if it is exactly one of the saved paths (stored paths are canonical).
    public func handleOpen(path: String) async -> OpenOutcome {
        let items: [SavedPath]
        do {
            items = try makeStore().load()
        } catch {
            return .listUnreadable(message: error.message)
        }
        guard items.contains(where: { $0.path == path }) else { return .notInList }
        guard folderStatus(path) == .folder else { return .folderMissing(path: path) }
        do {
            try await opener.openTerminal(at: URL(fileURLWithPath: path))
        } catch {
            return .failed(message: error.localizedDescription)
        }
        return .opened
    }
}
