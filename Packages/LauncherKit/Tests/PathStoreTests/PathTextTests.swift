import Foundation
import Testing
@testable import PathStore

private let home = "/Users/alex"

@Test(arguments: [
    (".", "/Users/alex/Documents", "/Users/alex/Documents"),
    ("api/", "/Users/alex/Projects", "/Users/alex/Projects/api"),
    ("../x/./y//", "/a/b", "/a/x/y"),
    ("/a/../../..", "/cwd", "/"),
    ("~", "/cwd", "/Users/alex"),
    ("~/code", "/cwd", "/Users/alex/code"),
    ("~bob", "/cwd", "/cwd/~bob"),
    ("/tmp", "/cwd", "/tmp"),  // symlinks are not resolved
    ("My Folder/ü & co", "/Users/alex", "/Users/alex/My Folder/ü & co"),
])
func canonicalize(raw: String, cwd: String, expected: String) {
    #expect(PathCanonicalizer.canonicalize(raw, cwd: cwd, home: home) == expected)
}

@Test(arguments: [
    ("/Users/alex/Documents", "~/Documents"),
    ("/Users/alex", "~"),
    ("/Users/alexander/x", "/Users/alexander/x"),
    ("/opt/x", "/opt/x"),
])
func abbreviated(path: String, expected: String) {
    #expect(PathDisplay.abbreviated(path, home: home) == expected)
}

@Test func nameAndParent() {
    #expect(PathDisplay.nameAndParent("/Users/alex/Projects/api", home: home) == ("api", "~/Projects"))
    #expect(PathDisplay.nameAndParent("/Users/alex/Documents", home: home) == ("Documents", "~"))
    #expect(PathDisplay.nameAndParent("/Users/alex", home: home) == ("~", ""))
    #expect(PathDisplay.nameAndParent("/opt", home: home) == ("opt", "/"))
    #expect(PathDisplay.nameAndParent("/", home: home) == ("/", ""))
}

@Test func realHomeIsTheUsersHome() {
    #expect(PathDisplay.realHome == FileManager.default.homeDirectoryForCurrentUser.path)
}
