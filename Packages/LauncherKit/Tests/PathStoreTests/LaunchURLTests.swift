import Foundation
import Testing
@testable import PathStore

@Test func reloadURL() {
    #expect(LaunchURL.reload.absoluteString == "tlaunch://reload")
    #expect(LaunchURL.parse(LaunchURL.reload) == .reload)
    #expect(LaunchURL.parse(URL(string: "TLAUNCH://reload")!) == .reload)
}

@Test func plainOpenURL() {
    #expect(LaunchURL.open(path: "/Users/alex/Projects/api").absoluteString == "tlaunch://open?path=/Users/alex/Projects/api")
}

@Test(arguments: ["/Users/alex/My Folder", "/a/b&c=d", "/a/1+1", "/a/#hash", "/a/100%", "/a/?q", "/Users/alex/Проекты/ü"])
func openRoundTrips(path: String) {
    #expect(LaunchURL.parse(LaunchURL.open(path: path)) == .open(path: path))
}

@Test(arguments: [
    "https://open?path=/x", "tlaunch://open", "tlaunch://open?path=", "tlaunch://open?path=relative",
    "tlaunch://open?path=/a&path=/b", "tlaunch://delete?path=/x", "tlaunch://",
])
func invalid(url: String) { #expect(LaunchURL.parse(URL(string: url)!) == .invalid) }
