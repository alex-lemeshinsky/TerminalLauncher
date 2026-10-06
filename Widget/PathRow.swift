import PathStore
import SwiftUI

struct PathRow: View {
    let path: String

    var body: some View {
        let parts = PathDisplay.nameAndParent(path, home: PathDisplay.realHome)
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(parts.name)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(parts.parent)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}
