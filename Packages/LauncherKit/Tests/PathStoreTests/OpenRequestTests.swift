import Foundation
import Testing
@testable import PathStore

private struct FakeError: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}

private actor FakeOpener: TerminalOpener {
    private(set) var opened: [URL] = []
    private let failure: FakeError?

    init(failure: FakeError? = nil) { self.failure = failure }

    func openTerminal(at folder: URL) async throws {
        if let failure { throw failure }
        opened.append(folder)
    }
}

private func makeHandler(
    seeding paths: [String]?,
    status: FolderStatus = .folder,
    opener: FakeOpener
) throws -> OpenRequestHandler {
    let store = PathStore(directory: makeTempDir())
    if let paths { try store.save(paths.map { sp($0) }) }
    return OpenRequestHandler(makeStore: { store }, folderStatus: { _ in status }, opener: opener)
}

@Test func opensListedFolder() async throws {
    let opener = FakeOpener()
    let handler = try makeHandler(seeding: ["/a/b"], opener: opener)
    #expect(await handler.handleOpen(path: "/a/b") == .opened)
    #expect(await opener.opened == [URL(fileURLWithPath: "/a/b")])
}

@Test func ignoresUnlistedPath() async throws {
    let opener = FakeOpener()
    let handler = try makeHandler(seeding: ["/a/b"], opener: opener)
    #expect(await handler.handleOpen(path: "/") == .notInList)
    #expect(await handler.handleOpen(path: "/a") == .notInList)
    #expect(await handler.handleOpen(path: "/a/b/c") == .notInList)
    #expect(await opener.opened.isEmpty)
}

@Test func missingListFileMeansNotInList() async throws {
    let opener = FakeOpener()
    let handler = try makeHandler(seeding: nil, opener: opener)
    #expect(await handler.handleOpen(path: "/a/b") == .notInList)
    #expect(await opener.opened.isEmpty)
}

@Test func missingFolderAlerts() async throws {
    let opener = FakeOpener()
    let handler = try makeHandler(seeding: ["/Users/alex/old/thing"], status: .missing, opener: opener)
    let outcome = await handler.handleOpen(path: "/Users/alex/old/thing")
    #expect(outcome == .folderMissing(path: "/Users/alex/old/thing"))
    #expect(outcome.alertMessage(home: "/Users/alex")
        == "~/old/thing no longer exists. Remove it with tl rm '~/old/thing'.")
    #expect(await opener.opened.isEmpty)
}

@Test func missingFolderAlertQuotesShellMetacharacters() {
    let outcome = OpenOutcome.folderMissing(path: "/Users/alex/it's $HOME \"x\"")
    #expect(outcome.alertMessage(home: "/Users/alex")
        == "~/it's $HOME \"x\" no longer exists. Remove it with tl rm '~/it'\\''s $HOME \"x\"'.")
}

@Test func fileInsteadOfFolderAlerts() async throws {
    let opener = FakeOpener()
    let handler = try makeHandler(seeding: ["/a/file"], status: .notFolder, opener: opener)
    #expect(await handler.handleOpen(path: "/a/file") == .folderMissing(path: "/a/file"))
    #expect(await opener.opened.isEmpty)
}

@Test func unreadableListIsIgnored() async throws {
    let opener = FakeOpener()
    let store = PathStore(directory: makeTempDir())
    try FileManager.default.createDirectory(at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("garbage".utf8).write(to: store.fileURL)
    let handler = OpenRequestHandler(makeStore: { store }, folderStatus: { _ in .folder }, opener: opener)
    let outcome = await handler.handleOpen(path: "/a/b")
    guard case let .listUnreadable(message) = outcome else {
        Issue.record("expected .listUnreadable, got \(outcome)")
        return
    }
    #expect(message.hasPrefix("couldn't read "))
    #expect(await opener.opened.isEmpty)
    #expect(outcome.alertMessage(home: "/Users/alex") == nil)
}

@Test func storeCreationFailureIsUnreadable() async {
    let opener = FakeOpener()
    let handler = OpenRequestHandler(
        makeStore: { () throws(PathStoreError) -> PathStore in throw .containerUnavailable(groupID: "g") },
        folderStatus: { _ in .folder },
        opener: opener)
    #expect(await handler.handleOpen(path: "/a/b") == .listUnreadable(message: "can't access App Group container g"))
}

@Test func openerFailureAlerts() async throws {
    let opener = FakeOpener(failure: FakeError("boom"))
    let handler = try makeHandler(seeding: ["/a/b"], opener: opener)
    let outcome = await handler.handleOpen(path: "/a/b")
    #expect(outcome == .failed(message: "boom"))
    #expect(outcome.alertMessage(home: "/Users/alex") == "Couldn't open Terminal: boom")
}

@Test func openedAndNotInListHaveNoAlert() {
    #expect(OpenOutcome.opened.alertMessage(home: "/Users/alex") == nil)
    #expect(OpenOutcome.notInList.alertMessage(home: "/Users/alex") == nil)
}
