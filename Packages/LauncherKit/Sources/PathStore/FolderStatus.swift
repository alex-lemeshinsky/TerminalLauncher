import Foundation

public enum FolderStatus: Equatable, Sendable {
    case folder, notFolder, missing

    /// Follows symlinks: a link to a folder is a `.folder`.
    public static func of(_ path: String) -> FolderStatus {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return .missing }
        return isDirectory.boolValue ? .folder : .notFolder
    }
}
