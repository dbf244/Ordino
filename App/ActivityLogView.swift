import OrdinoCore
import SwiftUI

/// A plain list of what Ordino noticed, newest first.
struct ActivityLogView: View {
    let model: AppModel

    var body: some View {
        Group {
            if model.log.entries.isEmpty {
                ContentUnavailableView {
                    Label("No Activity Yet", systemImage: "tray")
                } description: {
                    Text("Files that arrive in the watched folder will appear here.")
                }
            } else {
                List(model.log.entries) { entry in
                    ActivityRow(entry: entry)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 300)
    }
}

private struct ActivityRow: View {
    let entry: ActivityLog.Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Text(entry.date, format: .dateTime.hour().minute().second())
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch entry.activity {
        case .fileReady: "doc.badge.plus"
        case .fileRemoved: "minus.circle"
        case .fileRenamed: "pencil"
        case .folderUnavailable: "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch entry.activity {
        case .folderUnavailable: .orange
        default: .accentColor
        }
    }

    private var title: String {
        switch entry.activity {
        case .fileReady(let url), .fileRemoved(let url), .folderUnavailable(let url):
            url.lastPathComponent
        case .fileRenamed(_, let to):
            to.lastPathComponent
        }
    }

    private var detail: String {
        switch entry.activity {
        case .fileReady:
            String(localized: "Arrived or changed")
        case .fileRemoved:
            String(localized: "Deleted or moved away")
        case .fileRenamed(let from, _):
            String(localized: "Renamed from “\(from.lastPathComponent)”")
        case .folderUnavailable:
            String(localized: "Watched folder was moved or deleted")
        }
    }
}
