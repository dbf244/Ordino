import Foundation

/// A folder the user granted access to, as it is saved between launches.
public struct StoredFolder: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// The last known path, shown to the user if the bookmark stops working.
    public var path: String
    /// A security-scoped bookmark to the folder.
    public var bookmark: Data

    public init(id: UUID, path: String, bookmark: Data) {
        self.id = id
        self.path = path
        self.bookmark = bookmark
    }
}

/// Where granted folders are saved.
public protocol FolderStore: Sendable {
    func load() throws -> [StoredFolder]
    func save(_ folders: [StoredFolder]) throws
}

/// Saves granted folders as a small JSON file.
public struct JSONFolderStore: FolderStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `Application Support/Ordino/folders.json` (inside the app's sandbox container).
    public static func applicationSupport() throws -> JSONFolderStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return JSONFolderStore(fileURL: base.appendingPathComponent("Ordino", isDirectory: true)
            .appendingPathComponent("folders.json"))
    }

    public func load() throws -> [StoredFolder] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([StoredFolder].self, from: Data(contentsOf: fileURL))
    }

    public func save(_ folders: [StoredFolder]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(folders).write(to: fileURL, options: .atomic)
    }
}
