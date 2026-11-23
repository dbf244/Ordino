import Foundation

/// Where watched folders and their rules are saved.
/// A JSON file for now; the GRDB database replaces it in Achievement 5.
public protocol WatchedFolderStore: Sendable {
    func load() throws -> [WatchedFolder]
    func save(_ folders: [WatchedFolder]) throws
}

public struct JSONWatchedFolderStore: WatchedFolderStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `Application Support/Ordino/watched.json` (inside the app's sandbox container).
    public static func applicationSupport() throws -> JSONWatchedFolderStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return JSONWatchedFolderStore(fileURL: base.appendingPathComponent("Ordino", isDirectory: true)
            .appendingPathComponent("watched.json"))
    }

    public func load() throws -> [WatchedFolder] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([WatchedFolder].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ folders: [WatchedFolder]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(folders).write(to: fileURL, options: .atomic)
    }
}
