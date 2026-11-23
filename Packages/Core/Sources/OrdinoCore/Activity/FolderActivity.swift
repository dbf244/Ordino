import Foundation

/// Something Ordino noticed in a watched folder.
public enum FolderActivity: Sendable, Equatable, Hashable {
    /// A new or changed item that has stopped changing and is ready for rules.
    case fileReady(URL)
    /// An item was deleted or moved out of the folder.
    case fileRemoved(URL)
    /// An item was renamed inside the folder.
    case fileRenamed(from: URL, to: URL)
    /// The watched folder itself was moved, renamed or deleted.
    case folderUnavailable(URL)
}
