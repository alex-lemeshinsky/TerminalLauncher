import PathStore
import SwiftUI
import WidgetKit

struct PathsWidgetView: View {
    let entry: PathsEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .unreadable:
            message("Couldn't read list · run `tl ls`")
        case let .items(items) where items.isEmpty:
            message("No folders yet: run `tl .` in a folder")
        case let .items(items):
            // Try the most rows first and keep the first layout that fits the widget's height,
            // so each size shows as many folders as it has room for.
            ViewThatFits(in: .vertical) {
                ForEach((1...min(items.count, WidgetLayout.maxRows)).reversed(), id: \.self) { capacity in
                    rowList(WidgetLayout.rows(for: items, capacity: capacity))
                }
            }
        }
    }

    private func rowList(_ rows: (shown: [SavedPath], moreCount: Int)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows.shown, id: \.path) { item in
                Link(destination: LaunchURL.open(path: item.path)) {
                    PathRow(path: item.path)
                }
            }
            if rows.moreCount > 0 {
                Text("+\(rows.moreCount) more · tl ls")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}

#if DEBUG
private func sampleItems(_ count: Int) -> [SavedPath] {
    (1...max(count, 1)).prefix(count).map {
        SavedPath(path: PathDisplay.realHome + "/Projects/Sample\($0)", addedAt: .now)
    }
}

private let previewEntries: [PathsEntry] = [
    PathsEntry(date: .now, state: .items([])),
    PathsEntry(date: .now, state: .items(sampleItems(3))),
    PathsEntry(date: .now, state: .items(sampleItems(12))),
    PathsEntry(date: .now, state: .unreadable),
]

#Preview(as: .systemLarge) {
    PathsWidget()
} timeline: {
    for entry in previewEntries {
        entry
    }
}

#Preview(as: .systemMedium) {
    PathsWidget()
} timeline: {
    for entry in previewEntries {
        entry
    }
}
#endif
