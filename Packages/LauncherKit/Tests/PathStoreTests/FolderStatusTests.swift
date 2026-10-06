import Foundation
import Testing
@testable import PathStore

@Test func folderStatusOfFolderFileMissingAndSymlink() throws {
    let root = makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let fm = FileManager.default
    let sub = root.appendingPathComponent("sub")
    try fm.createDirectory(at: sub, withIntermediateDirectories: true)
    let file = root.appendingPathComponent("file.txt")
    try "hi".write(to: file, atomically: true, encoding: .utf8)
    let link = root.appendingPathComponent("link")
    try fm.createSymbolicLink(at: link, withDestinationURL: sub)

    #expect(FolderStatus.of(sub.path) == .folder)
    #expect(FolderStatus.of(file.path) == .notFolder)
    #expect(FolderStatus.of(root.appendingPathComponent("nope").path) == .missing)
    #expect(FolderStatus.of(link.path) == .folder)
}
