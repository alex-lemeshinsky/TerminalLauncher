import Testing
import Foundation
@testable import PathStore

@Test func loadMissingFileReturnsEmpty() throws {
    #expect(try PathStore(directory: makeTempDir()).load() == [])
}

@Test func saveThenLoadRoundTrips() throws {
    let store = PathStore(directory: makeTempDir())
    let items = [sp("/Users/alex/Documents"), sp("/opt/x", "2026-10-04T08:00:00Z")]
    try store.save(items)
    #expect(try store.load() == items)
}

@Test func fileMatchesSpecFormat() throws {
    let store = PathStore(directory: makeTempDir())
    try store.save([sp("/Users/alex/Documents")])
    let text = try String(contentsOf: store.fileURL, encoding: .utf8)
    #expect(!text.contains("\\/"))
    let json = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    #expect(json["version"] as? Int == 1)
    let items = try #require(json["items"] as? [[String: Any]])
    #expect(items[0]["path"] as? String == "/Users/alex/Documents")
    #expect(items[0]["addedAt"] as? String == "2026-10-05T11:02:00Z")
}

@Test func loadCorruptFileThrowsUnreadable() throws {
    let store = PathStore(directory: makeTempDir())
    try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: store.fileURL)
    do {
        _ = try store.load()
        Issue.record("expected load() to throw")
    } catch {
        guard case .unreadable(let file, _) = error else {
            Issue.record("wrong error: \(error)"); return
        }
        #expect(file == store.fileURL.path)
    }
}

@Test func loadUnknownVersionThrows() throws {
    let store = PathStore(directory: makeTempDir())
    try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(#"{"version":2,"items":[]}"#.utf8).write(to: store.fileURL)
    #expect(throws: PathStoreError.unsupportedVersion(file: store.fileURL.path, found: 2)) { try store.load() }
}

@Test func saveCreatesMissingDirectory() throws {
    let store = PathStore(directory: makeTempDir().appendingPathComponent("nested/dir"))
    try store.save([sp("/a")])
    #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
}

@Test func saveLeavesOnlyTheDataFile() throws {
    let dir = makeTempDir()
    let store = PathStore(directory: dir)
    try store.save([sp("/a")])
    try store.save([sp("/a"), sp("/b")])
    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["paths.json"])
}

@Test func errorMessages() {
    #expect(PathStoreError.unreadable(file: "/f", reason: "bad").message == "couldn't read /f: bad")
    #expect(PathStoreError.unsupportedVersion(file: "/f", found: 2).message == "/f has unsupported version 2")
    #expect(PathStoreError.containerUnavailable(groupID: "G").message == "can't access App Group container G")
    #expect(PathStoreError.writeFailed(file: "/f", reason: "x").message == "couldn't write /f: x")
}
