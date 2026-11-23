import Foundation

/// A folder Ordino watches, with its rules in the order they are checked.
public struct WatchedFolder: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// The granted folder (`StoredFolder.id`) being watched.
    public var folderID: UUID
    public var rules: [Rule]

    public init(id: UUID = UUID(), folderID: UUID, rules: [Rule]) {
        self.id = id
        self.folderID = folderID
        self.rules = rules
    }

    /// v0.1.0 saved granted folders but no watched list; its only granted
    /// folder was the watched one. Returns `watched` unchanged when there is
    /// already a list, or when it is not clear which folder was watched.
    public static func migrated(watched: [WatchedFolder], grantedFolderIDs: [UUID]) -> [WatchedFolder] {
        guard watched.isEmpty, grantedFolderIDs.count == 1, let only = grantedFolderIDs.first else {
            return watched
        }
        return [WatchedFolder(folderID: only, rules: [])]
    }
}
