import Foundation

public enum PathCanonicalizer {
    /// Turns a user-typed path into an absolute, normalized one. Works on strings only:
    /// it never touches the file system, so symlinks are not resolved.
    public static func canonicalize(_ raw: String, cwd: String, home: String) -> String {
        var path = raw
        if path == "~" {
            path = home
        } else if path.hasPrefix("~/") {
            path = home + String(path.dropFirst())
        }
        if !path.hasPrefix("/") {
            path = cwd + "/" + path
        }
        var kept: [Substring] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".": continue
            case "..": _ = kept.popLast()
            default: kept.append(component)
            }
        }
        return "/" + kept.joined(separator: "/")
    }
}
