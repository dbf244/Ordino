import Foundation

/// What a batch of FSEvents means for the items directly inside a watched folder.
public enum WatchChange: Sendable, Equatable {
    /// A new or changed item that may be ready once it stops changing.
    case candidate(URL)
    /// An item that is gone: deleted, or moved out of the folder.
    case removed(URL)
    /// An item renamed inside the folder.
    case renamed(from: URL, to: URL)
    /// The watched folder itself was moved, renamed or deleted.
    case rootChanged
    /// FSEvents dropped events; the folder must be scanned again.
    case rescan
}

/// Turns raw FSEvents records into `WatchChange`s.
///
/// FSEvents coalesces flags, so a single record can say "created" and
/// "removed" at once. The interpreter trusts the file system's current state
/// (`exists`) over the flags, and pairs renames by file ID.
/// Only direct children of the watched folder count: rules act on what
/// lands in a folder, not on what happens deep inside its subfolders.
struct EventInterpreter: Sendable {
    let rootPath: String

    init(rootPath: String) {
        self.rootPath = rootPath.count > 1 && rootPath.hasSuffix("/") ? String(rootPath.dropLast()) : rootPath
    }

    func interpret(_ records: [FSEventRecord], exists: (String) -> Bool) -> [WatchChange] {
        let ordered = records.sorted { $0.eventID < $1.eventID }

        if ordered.contains(where: { $0.flags.contains(.rootChanged) }) {
            return [.rootChanged]
        }
        if ordered.contains(where: { !$0.flags.isDisjoint(with: [.mustScanSubDirs, .userDropped, .kernelDropped]) }) {
            return [.rescan]
        }

        var changes: [WatchChange] = []
        var handled = Set<String>()

        // Renames come as two records (old path, new path) sharing a file ID.
        let renames = Dictionary(grouping: ordered.filter { $0.flags.contains(.itemRenamed) && $0.fileID != nil }) { $0.fileID }
        var pairedRenames: [String: WatchChange] = [:]
        for group in renames.values {
            let paths = uniquePaths(group)
            guard paths.count == 2 else { continue }
            let (old, new) = exists(paths[0]) ? (paths[1], paths[0]) : (paths[0], paths[1])
            guard !exists(old), exists(new) else { continue }
            let oldInside = isDirectChild(old) && !isIgnored(old)
            let newInside = isDirectChild(new) && !isIgnored(new)
            switch (oldInside, newInside) {
            case (true, true):
                pairedRenames[old] = .renamed(from: url(old), to: url(new))
            case (true, false):
                pairedRenames[old] = .removed(url(old))
            case (false, true):
                pairedRenames[old] = .candidate(url(new))
            case (false, false):
                break
            }
            handled.insert(old)
            handled.insert(new)
        }

        for record in ordered {
            let path = record.path
            if let change = pairedRenames.removeValue(forKey: path) {
                changes.append(change)
                continue
            }
            guard !handled.contains(path) else { continue }
            handled.insert(path)
            guard isDirectChild(path), !isIgnored(path) else { continue }
            changes.append(exists(path) ? .candidate(url(path)) : .removed(url(path)))
        }
        return changes
    }

    private func uniquePaths(_ records: [FSEventRecord]) -> [String] {
        var seen: [String] = []
        for record in records where !seen.contains(record.path) {
            seen.append(record.path)
        }
        return seen
    }

    private func isDirectChild(_ path: String) -> Bool {
        (path as NSString).deletingLastPathComponent == rootPath
    }

    private func isIgnored(_ path: String) -> Bool {
        FileFilter.isIgnored(URL(fileURLWithPath: path))
    }

    private func url(_ path: String) -> URL {
        URL(fileURLWithPath: path)
    }
}
