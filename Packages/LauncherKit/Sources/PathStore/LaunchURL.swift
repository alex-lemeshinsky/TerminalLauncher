import Foundation

public enum LaunchAction: Equatable, Sendable {
    case open(path: String)
    case reload
    case invalid
}

/// Builds and parses the `tlaunch://` URLs shared by the widget, the app and the CLI.
public enum LaunchURL {
    public static let scheme = "tlaunch"

    /// `.urlQueryAllowed` minus the characters that would be misread inside a query value.
    private static let valueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&=+?#")
        return set
    }()

    public static func open(path: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        let encoded = path.addingPercentEncoding(withAllowedCharacters: valueAllowed) ?? path
        components.percentEncodedQueryItems = [URLQueryItem(name: "path", value: encoded)]
        return components.url!
    }

    public static var reload: URL {
        URL(string: "\(scheme)://reload")!
    }

    public static func parse(_ url: URL) -> LaunchAction {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme
        else { return .invalid }

        switch components.host {
        case "reload":
            return components.query == nil ? .reload : .invalid
        case "open":
            guard let items = components.queryItems, items.count == 1,
                  items[0].name == "path",
                  let path = items[0].value, path.hasPrefix("/")
            else { return .invalid }
            return .open(path: path)
        default:
            return .invalid
        }
    }
}
