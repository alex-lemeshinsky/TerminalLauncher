import Foundation

public enum PathStoreError: Error, Equatable, Sendable {
    case unreadable(file: String, reason: String)
    case unsupportedVersion(file: String, found: Int)
    case containerUnavailable(groupID: String)
    case writeFailed(file: String, reason: String)

    public var message: String {
        switch self {
        case let .unreadable(file, reason): "couldn't read \(file): \(reason)"
        case let .unsupportedVersion(file, found): "\(file) has unsupported version \(found)"
        case let .containerUnavailable(groupID): "can't access App Group container \(groupID)"
        case let .writeFailed(file, reason): "couldn't write \(file): \(reason)"
        }
    }
}

public struct PathStore: Sendable {
    public static let appGroupID = "A5STTR22DU.com.alex.TerminalLauncher"
    public static let fileName = "paths.json"

    public let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent(Self.fileName)
    }

    public static func appGroup() throws(PathStoreError) -> PathStore {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            throw .containerUnavailable(groupID: appGroupID)
        }
        return PathStore(directory: container)
    }

    /// Returns the saved paths; a missing file is an empty list.
    public func load() throws(PathStoreError) -> [SavedPath] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return []
        } catch {
            throw .unreadable(file: fileURL.path, reason: error.localizedDescription)
        }
        let list: PathList
        do {
            list = try Self.decoder.decode(PathList.self, from: data)
        } catch {
            throw .unreadable(file: fileURL.path, reason: error.localizedDescription)
        }
        guard list.version == PathList.currentVersion else {
            throw .unsupportedVersion(file: fileURL.path, found: list.version)
        }
        return list.items
    }

    public func save(_ items: [SavedPath]) throws(PathStoreError) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try Self.encoder.encode(PathList(items: items))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw .writeFailed(file: fileURL.path, reason: error.localizedDescription)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
