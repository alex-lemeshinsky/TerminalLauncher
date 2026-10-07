import PathStore
import SwiftUI

struct PathRow: View {
    let path: String
    /// The small widget is too narrow for the parent folder, so it shows only the name.
    var showsParent = true

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
            if showsParent {
                Text(parts.parent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.callout)
    }
}
