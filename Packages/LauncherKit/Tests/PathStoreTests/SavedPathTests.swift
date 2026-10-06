import Testing
import Foundation
@testable import PathStore

@Test func addToEmpty() {
    let r = [SavedPath]().addingToTop("/a", at: iso("2026-10-05T12:00:00Z"))
    #expect(r.items == [sp("/a", "2026-10-05T12:00:00Z")]); #expect(!r.alreadyPresent)
}
@Test func addNewGoesFirst() {
    #expect([sp("/a"), sp("/b")].addingToTop("/p", at: iso("2026-10-05T12:00:00Z")).items.map(\.path) == ["/p", "/a", "/b"])
}
@Test func addExistingMovesToTopWithNewDate() {
    let r = [sp("/a"), sp("/b"), sp("/c")].addingToTop("/b", at: iso("2026-10-06T00:00:00Z"))
    #expect(r.items == [sp("/b", "2026-10-06T00:00:00Z"), sp("/a"), sp("/c")]); #expect(r.alreadyPresent)
}
@Test func removeByNumber() {
    let r = [sp("/a"), sp("/b"), sp("/c")].removing(number: 2)
    #expect(r?.items.map(\.path) == ["/a", "/c"]); #expect(r?.removed.path == "/b")
}
@Test func removeByNumberOutOfRange() {
    #expect([sp("/a")].removing(number: 0) == nil); #expect([sp("/a")].removing(number: 2) == nil)
}
@Test func removeByPath() {
    #expect([sp("/a"), sp("/b")].removing(path: "/a")?.items.map(\.path) == ["/b"])
    #expect([sp("/a")].removing(path: "/x") == nil)
}
@Test(arguments: [(0, 10, 0, 0), (10, 10, 10, 0), (12, 10, 9, 3), (11, 10, 9, 2), (4, 4, 4, 0), (5, 4, 3, 2)])
func widgetRows(count: Int, capacity: Int, shown: Int, more: Int) {
    let items = (0..<count).map { sp("/p\($0)") }
    let r = WidgetLayout.rows(for: items, capacity: capacity)
    #expect(r.shown == Array(items.prefix(shown))); #expect(r.moreCount == more)
}
