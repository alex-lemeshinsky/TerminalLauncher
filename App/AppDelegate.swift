import AppKit
import OSLog
import PathStore
import WidgetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.alex.TerminalLauncher", category: "app")
    private let handler = OpenRequestHandler(
        makeStore: PathStore.appGroup,
        folderStatus: FolderStatus.of,
        opener: WorkspaceTerminalOpener()
    )

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch LaunchURL.parse(url) {
            case .reload:
                WidgetCenter.shared.reloadAllTimelines()
                logger.notice("Reloaded widget timelines")
            case let .open(path):
                Task { await open(path: path) }
            case .invalid:
                logger.notice("Ignored invalid URL \(url.absoluteString, privacy: .public)")
            }
        }
    }

    private func open(path: String) async {
        let outcome = await handler.handleOpen(path: path)
        logger.notice("Open \(path, privacy: .public): \(String(describing: outcome), privacy: .public)")
        guard let message = outcome.alertMessage(home: PathDisplay.realHome) else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "TerminalLauncher"
        alert.informativeText = message
        alert.runModal()
    }
}
