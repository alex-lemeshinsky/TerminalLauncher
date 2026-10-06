import AppKit
import PathStore

struct TerminalNotFoundError: LocalizedError {
    var errorDescription: String? { "Terminal.app not found" }
}

/// Opens a folder in Terminal.app through NSWorkspace.
struct WorkspaceTerminalOpener: TerminalOpener {
    func openTerminal(at folder: URL) async throws {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw TerminalNotFoundError()
        }
        try await NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: .init())
    }
}
