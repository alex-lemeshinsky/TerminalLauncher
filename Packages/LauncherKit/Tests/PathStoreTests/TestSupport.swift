import Foundation
@testable import PathStore

func makeTempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

func iso(_ s: String) -> Date {
    try! Date(s, strategy: .iso8601)
}

func sp(_ path: String, _ date: String = "2026-10-05T11:02:00Z") -> SavedPath {
    SavedPath(path: path, addedAt: iso(date))
}
