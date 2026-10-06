import OSLog
import PathStore
import SwiftUI
import WidgetKit

struct PathsEntry: TimelineEntry {
    enum State {
        case items([SavedPath])
        case unreadable
    }

    let date: Date
    let state: State
}

struct Provider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.alex.TerminalLauncher", category: "widget")

    func placeholder(in context: Context) -> PathsEntry {
        PathsEntry(date: .now, state: .items(Self.samplePaths))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (PathsEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PathsEntry>) -> Void) {
        let refresh = Date.now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [loadEntry()], policy: .after(refresh)))
    }

    private func loadEntry() -> PathsEntry {
        do {
            let items = try PathStore.appGroup().load()
            return PathsEntry(date: .now, state: .items(items))
        } catch {
            Self.logger.notice("Couldn't load saved paths: \(error.message, privacy: .public)")
            return PathsEntry(date: .now, state: .unreadable)
        }
    }

    static let samplePaths: [SavedPath] = [
        SavedPath(path: PathDisplay.realHome + "/Projects/App", addedAt: .now),
        SavedPath(path: PathDisplay.realHome + "/Documents", addedAt: .now),
        SavedPath(path: "/usr/local/bin", addedAt: .now),
    ]
}

@main
struct PathsWidget: Widget {
    let kind = "PathsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PathsWidgetView(entry: entry)
        }
        .configurationDisplayName("Terminal Folders")
        .description("Open Terminal in a saved folder.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
