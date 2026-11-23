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
        case .fileMoved: "arrow.right.doc.on.clipboard"
        case .folderUnavailable, .actionFailed: "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch entry.activity {
        case .folderUnavailable, .actionFailed: .orange
        default: .accentColor
        }
    }

    private var title: String {
        switch entry.activity {
        case .fileReady(let url), .fileRemoved(let url), .folderUnavailable(let url):
            url.lastPathComponent
        case .fileRenamed(_, let to), .fileMoved(_, let to, _):
            to.lastPathComponent
        case .actionFailed(let url, _, _):
            url.lastPathComponent
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
        case .fileMoved(_, let to, let rule):
            String(localized: "Moved to “\(to.deletingLastPathComponent().lastPathComponent)” by “\(rule)”")
        case .actionFailed(_, let rule, let reason):
            String(localized: "“\(rule)” couldn't run: \(Self.describe(reason))")
        }
    }

    private static func describe(_ failure: ActionFailure) -> String {
        switch failure {
        case .destinationUnavailable:
            String(localized: "the destination folder isn't available")
        case .moveFailed(let error):
            switch error {
            case .sourceMissing: String(localized: "the file is gone")
            case .destinationMissing: String(localized: "the destination folder is missing")
            case .alreadyInDestination: String(localized: "it's already in the destination")
            case .destinationInsideSource: String(localized: "a folder can't go inside itself")
            case .noFreeName: String(localized: "no free name in the destination")
            case .moveFailed(let message): message
            }
        }
    }
}
