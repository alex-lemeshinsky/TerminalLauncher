import Foundation

public struct SavedPath: Codable, Equatable, Sendable {
    public var path: String
    public var addedAt: Date

    public init(path: String, addedAt: Date) {
        self.path = path
        self.addedAt = addedAt
    }
}

public struct PathList: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var items: [SavedPath]

    public init(version: Int = PathList.currentVersion, items: [SavedPath]) {
        self.version = version
        self.items = items
    }
}

extension Array where Element == SavedPath {
    /// Puts `path` at the top of the list. An existing entry with the same path is replaced
    /// (moved to the top with the new date) and `alreadyPresent` is `true`.
    public func addingToTop(_ path: String, at date: Date) -> (items: [SavedPath], alreadyPresent: Bool) {
        var items = self
        let before = items.count
        items.removeAll { $0.path == path }
        let alreadyPresent = items.count != before
        items.insert(SavedPath(path: path, addedAt: date), at: 0)
        return (items, alreadyPresent)
    }

    /// Removes the entry at the 1-based `number`, or returns `nil` when it is out of range.
    public func removing(number: Int) -> (items: [SavedPath], removed: SavedPath)? {
        guard indices.contains(number - 1) else { return nil }
        var items = self
        let removed = items.remove(at: number - 1)
        return (items, removed)
    }

    /// Removes the entry with exactly this `path`, or returns `nil` when there is none.
    public func removing(path: String) -> (items: [SavedPath], removed: SavedPath)? {
        guard let index = firstIndex(where: { $0.path == path }) else { return nil }
        var items = self
        let removed = items.remove(at: index)
        return (items, removed)
    }
}

public enum WidgetLayout {
    /// The most rows any widget draws. Each size shows as many rows as fit its height, up to this.
    public static let maxRows = 10

    /// Rows to draw in a widget with `capacity` rows. When the list doesn't fit, the last row is
    /// reserved for a "+N more" line, so only `capacity - 1` paths are shown.
    public static func rows(for items: [SavedPath], capacity: Int) -> (shown: [SavedPath], moreCount: Int) {
        if items.count <= capacity { return (items, 0) }
        let shownCount = capacity - 1
        return (Array(items.prefix(shownCount)), items.count - shownCount)
    }
}
