import Foundation

public enum FolderAccessError: Error, Sendable, Equatable {
    /// The folder is `/`, a system folder or `~/Library`.
    case protectedPath(String)
    /// The URL is not a folder.
    case notAFolder(String)
    /// The folder cannot be found any more (deleted, or on a disconnected drive).
    case folderMissing(String)
    /// The bookmark resolved, but macOS refused access. The user must choose the folder again.
    case accessDenied(String)
    /// The bookmark could not be created.
    case bookmarkFailed(String)
    /// The list of folders could not be saved.
    case saveFailed
}

public enum FolderAvailability: Sendable, Equatable {
    case available(URL)
    case unavailable(FolderAccessError)
}

public struct RestoredFolder: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let path: String
    public let availability: FolderAvailability
}

/// Remembers the folders the user chose, so access survives relaunches.
///
/// Access only ever comes from the user picking a folder (`NSOpenPanel` in the
/// app). This type turns that choice into a security-scoped bookmark, saves it,
/// and resolves it again on the next launch. A folder whose bookmark stops
/// working is kept and reported as unavailable, never silently dropped.
public actor FolderAccess {
    private let store: any FolderStore
    private let isProtected: @Sendable (URL) -> Bool
    private var folders: [StoredFolder]
    private var accessing: [UUID: URL] = [:]

    /// - Parameter isProtected: decides which folders may never be granted.
    ///   Tests replace it to use temporary folders, which live in a protected location.
    public init(store: any FolderStore, isProtected: @escaping @Sendable (URL) -> Bool = { ProtectedPaths.isProtected($0) }) {
        self.store = store
        self.isProtected = isProtected
        self.folders = (try? store.load()) ?? []
    }

    deinit {
        for url in accessing.values {
            url.stopAccessingSecurityScopedResource()
        }
    }

    /// Saves access to a folder the user just picked. Granting the same folder
    /// again refreshes its bookmark and keeps its identity.
    @discardableResult
    public func grant(_ url: URL) throws -> StoredFolder {
        // Check both the path as given and with symlinks resolved, so that
        // e.g. /tmp (→ /private/tmp) cannot slip past the protected list.
        let folder = URL(fileURLWithPath: canonicalPath(url.path), isDirectory: true)
        guard !isProtected(url), !isProtected(folder) else {
            throw FolderAccessError.protectedPath(url.path)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) else {
            throw FolderAccessError.folderMissing(folder.path)
        }
        guard isDirectory.boolValue else {
            throw FolderAccessError.notAFolder(folder.path)
        }

        let bookmark = try makeBookmark(for: folder)
        let stored: StoredFolder
        if let index = folders.firstIndex(where: { $0.path == folder.path }) {
            folders[index].bookmark = bookmark
            stored = folders[index]
        } else {
            stored = StoredFolder(id: UUID(), path: folder.path, bookmark: bookmark)
            folders.append(stored)
        }
        try persist()
        return stored
    }

    /// Resolves every saved folder and starts accessing the ones that work.
    /// Stale bookmarks (folder moved or renamed) are refreshed and saved.
    public func restore() -> [RestoredFolder] {
        var results: [RestoredFolder] = []
        var changed = false
        for index in folders.indices {
            let folder = folders[index]
            let availability = resolve(folder, updating: &folders[index], changed: &changed)
            results.append(RestoredFolder(id: folder.id, path: folders[index].path, availability: availability))
        }
        if changed {
            try? persist()
        }
        return results
    }

    /// Forgets a folder and gives up access to it.
    public func revoke(_ id: UUID) throws {
        accessing.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
        folders.removeAll { $0.id == id }
        try persist()
    }

    private func resolve(_ folder: StoredFolder, updating stored: inout StoredFolder, changed: inout Bool) -> FolderAvailability {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: folder.bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            return .unavailable(.folderMissing(folder.path))
        }

        if accessing[folder.id] == nil {
            guard url.startAccessingSecurityScopedResource() else {
                return .unavailable(.accessDenied(url.path))
            }
            accessing[folder.id] = url
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            accessing.removeValue(forKey: folder.id)?.stopAccessingSecurityScopedResource()
            return .unavailable(.folderMissing(url.path))
        }

        let resolved = URL(fileURLWithPath: url.path, isDirectory: true)
        if isStale || stored.path != resolved.path {
            if let fresh = try? makeBookmark(for: resolved) {
                stored.bookmark = fresh
            }
            stored.path = resolved.path
            changed = true
        }
        return .available(resolved)
    }

    private func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw FolderAccessError.bookmarkFailed(url.path)
        }
    }

    private func persist() throws {
        do {
            try store.save(folders)
        } catch {
            throw FolderAccessError.saveFailed
        }
    }
}
