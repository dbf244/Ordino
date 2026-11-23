import Foundation

/// What a file or folder looks like right now. If two signatures taken a
/// while apart are equal, nothing was written in between.
struct FileSignature: Sendable, Equatable {
    let size: Int64
    let modified: Date
    /// For folders: how many items are inside, at any depth.
    let itemCount: Int

    /// Reads the signature from disk, or `nil` if the item does not exist.
    /// Folders are measured recursively, so a folder still being copied keeps changing.
    static func read(_ url: URL) -> FileSignature? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        let modified = attributes[.modificationDate] as? Date ?? .distantPast
        guard attributes[.type] as? FileAttributeType == .typeDirectory else {
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            return FileSignature(size: size, modified: modified, itemCount: 0)
        }

        var size: Int64 = 0
        var latest = modified
        var count = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) {
            for case let item as URL in enumerator {
                count += 1
                let values = try? item.resourceValues(forKeys: Set(keys))
                size += Int64(values?.fileSize ?? 0)
                if let date = values?.contentModificationDate, date > latest {
                    latest = date
                }
            }
        }
        return FileSignature(size: size, modified: latest, itemCount: count)
    }
}
