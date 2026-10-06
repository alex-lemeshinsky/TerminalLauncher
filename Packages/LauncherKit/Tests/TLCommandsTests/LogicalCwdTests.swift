import Foundation
import Testing
@testable import TLCommands

@Suite struct LogicalCwdTests {
    @Test func matchingPwdIsUsed() {
        let result = logicalCwd(pwd: "/Users/alex/link", physical: "/private/real", sameFile: { _, _ in true })
        #expect(result == "/Users/alex/link")
    }

    @Test func nilPwdFallsBackToPhysical() {
        let result = logicalCwd(pwd: nil, physical: "/private/real", sameFile: { _, _ in true })
        #expect(result == "/private/real")
    }

    @Test func relativePwdFallsBack() {
        let result = logicalCwd(pwd: "link", physical: "/private/real", sameFile: { _, _ in true })
        #expect(result == "/private/real")
    }

    @Test func pwdWithDotComponentsFallsBack() {
        #expect(logicalCwd(pwd: "/Users/alex/../link", physical: "/private/real", sameFile: { _, _ in true })
            == "/private/real")
        #expect(logicalCwd(pwd: "/Users/alex/./link", physical: "/private/real", sameFile: { _, _ in true })
            == "/private/real")
    }

    @Test func pwdWithDotsInsideNamesIsKept() {
        let result = logicalCwd(pwd: "/Users/alex/my..dir/.hidden", physical: "/private/real", sameFile: { _, _ in true })
        #expect(result == "/Users/alex/my..dir/.hidden")
    }

    @Test func differentFileFallsBack() {
        let result = logicalCwd(pwd: "/Users/alex/link", physical: "/private/real", sameFile: { _, _ in false })
        #expect(result == "/private/real")
    }

    @Test func sameFileOnDiskFollowsSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let target = root.appendingPathComponent("target")
        let other = root.appendingPathComponent("other")
        let link = root.appendingPathComponent("link")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(sameFileOnDisk(link.path, target.path))
        #expect(!sameFileOnDisk(target.path, other.path))
        #expect(!sameFileOnDisk(target.path, root.appendingPathComponent("missing").path))
        #expect(logicalCwd(pwd: link.path, physical: target.path, sameFile: sameFileOnDisk) == link.path)
    }
}
