import Foundation

public enum PathDisplay {
    /// The user's real home folder. Unlike `NSHomeDirectory()`, this is not the container
    /// path inside a sandboxed process.
    public static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Replaces `home` with `~` when the path is the home folder or lies inside it.
    public static func abbreviated(_ path: String, home: String) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    /// Splits a path into its last component and the abbreviated parent folder.
    public static func nameAndParent(_ path: String, home: String) -> (name: String, parent: String) {
        if path == "/" { return ("/", "") }
        if path == home { return ("~", "") }
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        return (url.lastPathComponent, abbreviated(parent, home: home))
    }
}
