import Foundation

/// The most recent activity, newest first, with a fixed capacity so memory
/// stays bounded however long the app runs.
public struct ActivityLog: Sendable, Equatable {
    public struct Entry: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let date: Date
        public let activity: FolderActivity
    }

    public let capacity: Int
    public private(set) var entries: [Entry] = []

    public init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    public mutating func record(_ activity: FolderActivity, at date: Date = .now) {
        entries.insert(Entry(id: UUID(), date: date, activity: activity), at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
    }
}
