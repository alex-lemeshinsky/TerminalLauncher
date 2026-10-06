import Foundation
import Testing
@testable import PathStore
@testable import TLCommands

private actor FakeReloader: WidgetReloader {
    let result: Bool
    private(set) var calls = 0

    init(result: Bool = true) { self.result = result }

    func requestReload() async -> Bool {
        calls += 1
        return result
    }
}

private func makeTempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func iso(_ s: String) -> Date {
    try! Date(s, strategy: .iso8601)
}

private let now = iso("2026-10-05T12:00:00Z")

private struct Harness {
    let directory = makeTempDir()
    let reloader: FakeReloader
    let commands: Commands
    var store: PathStore { PathStore(directory: directory) }

    init(
        statuses: [String: FolderStatus] = [:],
        reloadResult: Bool = true,
        makeStore: (@Sendable () throws(PathStoreError) -> PathStore)? = nil
    ) {
        let directory = directory
        let reloader = FakeReloader(result: reloadResult)
        self.reloader = reloader
        commands = Commands(
            makeStore: makeStore ?? { PathStore(directory: directory) },
            reloader: reloader,
            folderStatus: { statuses[$0] ?? .missing },
            cwd: "/Users/alex/Documents",
            home: "/Users/alex",
            now: { now }
        )
    }

    func seed(_ paths: [String]) throws {
        try store.save(paths.map { SavedPath(path: $0, addedAt: iso("2026-10-05T11:02:00Z")) })
    }

    func storedPaths() throws -> [String] {
        try store.load().map(\.path)
    }

    var reloadCalls: Int {
        get async { await reloader.calls }
    }
}

private let reloadFailedLine =
    "Saved, but couldn't reach TerminalLauncher.app; the widget will update within 30 minutes."

@Suite struct AddTests {
    @Test func addNewFolder() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder])
        let result = await h.commands.add(".")
        #expect(result == CommandResult(stdout: ["Added ~/Documents"], stderr: [], exitCode: 0))
        #expect(try h.storedPaths() == ["/Users/alex/Documents"])
        #expect(await h.reloadCalls == 1)
    }

    @Test func addExistingMovesToTop() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder])
        try h.seed(["/Users/alex/Projects", "/Users/alex/Documents"])
        let result = await h.commands.add(".")
        #expect(result.stdout == ["~/Documents already saved, moved to top"])
        #expect(result.exitCode == 0)
        let items = try h.store.load()
        #expect(items.map(\.path) == ["/Users/alex/Documents", "/Users/alex/Projects"])
        #expect(items[0].addedAt == now)
    }

    @Test func addMissingFolder() async throws {
        let h = Harness()
        let result = await h.commands.add(".")
        #expect(result == CommandResult(stdout: [], stderr: ["Error: ~/Documents does not exist"], exitCode: 1))
        #expect(!FileManager.default.fileExists(atPath: h.store.fileURL.path))
        #expect(await h.reloadCalls == 0)
    }

    @Test func addNotAFolder() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents/notes.txt": .notFolder])
        let result = await h.commands.add("notes.txt")
        #expect(result == CommandResult(
            stdout: [], stderr: ["Error: ~/Documents/notes.txt is not a folder"], exitCode: 1))
        #expect(await h.reloadCalls == 0)
    }

    @Test func addEleventhPrintsNote() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder])
        try h.seed((1...10).map { "/Users/alex/p\($0)" })
        let result = await h.commands.add(".")
        #expect(result.stdout == [
            "Added ~/Documents",
            "Note: the widget shows up to 10 folders; 2 are hidden.",
        ])
        #expect(result.exitCode == 0)
    }

    @Test func addWhenReloadFails() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder], reloadResult: false)
        let result = await h.commands.add(".")
        #expect(result == CommandResult(
            stdout: ["Added ~/Documents"], stderr: [reloadFailedLine], exitCode: 0))
        #expect(try h.storedPaths() == ["/Users/alex/Documents"])
    }

    @Test func addWithCorruptFileDoesNotOverwrite() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder])
        try FileManager.default.createDirectory(at: h.directory, withIntermediateDirectories: true)
        try "garbage".write(to: h.store.fileURL, atomically: true, encoding: .utf8)
        let result = await h.commands.add(".")
        #expect(result.exitCode == 1)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.count == 1)
        #expect(result.stderr[0].hasPrefix("Error: couldn't read "))
        #expect(try String(contentsOf: h.store.fileURL, encoding: .utf8) == "garbage")
        #expect(await h.reloadCalls == 0)
    }

    @Test func addWhenContainerUnavailable() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder]) { () throws(PathStoreError) -> PathStore in
            throw .containerUnavailable(groupID: PathStore.appGroupID)
        }
        let result = await h.commands.add(".")
        #expect(result == CommandResult(
            stdout: [],
            stderr: ["Error: can't access App Group container \(PathStore.appGroupID)"],
            exitCode: 1))
        #expect(await h.reloadCalls == 0)
    }
}

@Suite struct RemoveTests {
    @Test func removeByNumber() async throws {
        let h = Harness()
        try h.seed(["/Users/alex/a", "/Users/alex/b", "/Users/alex/c"])
        let result = await h.commands.remove("2")
        #expect(result == CommandResult(stdout: ["Removed ~/b"], stderr: [], exitCode: 0))
        #expect(try h.storedPaths() == ["/Users/alex/a", "/Users/alex/c"])
        #expect(await h.reloadCalls == 1)
    }

    @Test func removeByPath() async throws {
        let h = Harness()
        try h.seed(["/Users/alex/Documents"])
        let result = await h.commands.remove(".")
        #expect(result.stdout == ["Removed ~/Documents"])
        #expect(result.exitCode == 0)
        #expect(try h.storedPaths() == [])
    }

    @Test func removeDeletedFolderByPath() async throws {
        let h = Harness()
        try h.seed(["/Users/alex/old/thing"])
        let result = await h.commands.remove("~/old/thing")
        #expect(result == CommandResult(stdout: ["Removed ~/old/thing"], stderr: [], exitCode: 0))
    }

    @Test func removeNumberOutOfRange() async throws {
        let h = Harness()
        try h.seed(["/Users/alex/a", "/Users/alex/b", "/Users/alex/c"])
        for (target, shown) in [("4", "4"), ("0", "0"), ("99999999999999999999999", "99999999999999999999999")] {
            let result = await h.commands.remove(target)
            #expect(result == CommandResult(
                stdout: [], stderr: ["Error: no item number \(shown) (the list has 3)"], exitCode: 1))
        }
        #expect(try h.storedPaths().count == 3)
        #expect(await h.reloadCalls == 0)
    }

    @Test func removeUnknownPath() async throws {
        let h = Harness()
        let result = await h.commands.remove(".")
        #expect(result == CommandResult(
            stdout: [], stderr: ["Error: ~/Documents is not in the list"], exitCode: 1))
        #expect(await h.reloadCalls == 0)
    }

    @Test func removeWhenReloadFails() async throws {
        let h = Harness(reloadResult: false)
        try h.seed(["/Users/alex/a"])
        let result = await h.commands.remove("1")
        #expect(result == CommandResult(
            stdout: ["Removed ~/a"], stderr: [reloadFailedLine], exitCode: 0))
    }
}

@Suite struct ListTests {
    @Test func listEmpty() async throws {
        let h = Harness()
        let result = h.commands.list()
        #expect(result == CommandResult(
            stdout: ["No folders yet. Run \"tl .\" in a folder."], stderr: [], exitCode: 0))
        #expect(await h.reloadCalls == 0)
    }

    @Test func listNumbered() async throws {
        let h = Harness(statuses: ["/Users/alex/Documents": .folder])
        try h.seed(["/Users/alex/Documents", "/Users/alex/old/thing"])
        let result = h.commands.list()
        #expect(result == CommandResult(
            stdout: [" 1  ~/Documents", " 2  ~/old/thing   (missing)"], stderr: [], exitCode: 0))
    }

    @Test func listCorrupt() async throws {
        let h = Harness()
        try FileManager.default.createDirectory(at: h.directory, withIntermediateDirectories: true)
        try "garbage".write(to: h.store.fileURL, atomically: true, encoding: .utf8)
        let result = h.commands.list()
        #expect(result.exitCode == 1)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.count == 1)
        #expect(result.stderr[0].hasPrefix("Error: couldn't read "))
    }
}
