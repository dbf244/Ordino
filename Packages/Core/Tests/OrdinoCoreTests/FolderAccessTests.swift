import Foundation
import OrdinoCore
import Testing

@Suite("FolderAccess")
struct FolderAccessTests {
    let storage: TemporaryFolder
    let store: JSONFolderStore

    init() throws {
        storage = try TemporaryFolder()
        store = JSONFolderStore(fileURL: storage.url.appendingPathComponent("folders.json"))
    }

    /// Temporary folders live under /private/var, which is protected, so most
    /// tests use an access that protects nothing. The protection itself is
    /// tested with the real rules below.
    func access() -> FolderAccess {
        FolderAccess(store: store, isProtected: { _ in false })
    }

    @Test("An empty store loads as no folders")
    func emptyStore() throws {
        #expect(try store.load().isEmpty)
    }

    @Test("The store round-trips folders through JSON")
    func storeRoundTrip() throws {
        let folders = [StoredFolder(id: UUID(), path: "/Users/someone/Downloads", bookmark: Data([1, 2, 3]))]
        try store.save(folders)
        #expect(try store.load() == folders)
    }

    @Test("A granted folder is restored after a relaunch")
    func grantAndRestore() async throws {
        let watched = try TemporaryFolder()
        let granted = try await access().grant(watched.url)

        // A new FolderAccess with the same store stands in for a relaunch.
        let restored = await access().restore()

        #expect(restored.count == 1)
        #expect(restored.first?.id == granted.id)
        #expect(restored.first?.availability == .available(watched.url))
    }

    @Test("Granting the same folder twice keeps a single entry")
    func grantTwice() async throws {
        let watched = try TemporaryFolder()
        let access = self.access()
        let first = try await access.grant(watched.url)
        let second = try await access.grant(watched.url)
        #expect(first.id == second.id)
        #expect(try store.load().count == 1)
    }

    @Test("A folder that no longer exists is restored as unavailable, not dropped")
    func missingFolder() async throws {
        var watched: TemporaryFolder? = try TemporaryFolder()
        let path = try #require(watched?.url.path)
        _ = try await access().grant(#require(watched?.url))
        watched = nil  // deletes the folder

        let restored = await access().restore()

        #expect(restored.count == 1)
        #expect(restored.first?.path == path)
        guard case .unavailable = restored.first?.availability else {
            Issue.record("Expected the folder to be unavailable, got \(String(describing: restored.first?.availability))")
            return
        }
        #expect(try store.load().count == 1)
    }

    @Test("A moved folder is found again by its bookmark and its path is updated")
    func movedFolder() async throws {
        let parent = try TemporaryFolder()
        let original = try parent.makeFolder("Before")
        let granted = try await access().grant(original)
        let moved = parent.url.appendingPathComponent("After", isDirectory: true)
        try FileManager.default.moveItem(at: original, to: moved)

        let restored = await access().restore()

        #expect(restored.first?.id == granted.id)
        #expect(restored.first?.availability == .available(moved))
        #expect(try store.load().first?.path == moved.path)
    }

    @Test("Revoking a folder forgets it")
    func revoke() async throws {
        let watched = try TemporaryFolder()
        let access = self.access()
        let granted = try await access.grant(watched.url)
        try await access.revoke(granted.id)
        #expect(try store.load().isEmpty)
        #expect(await self.access().restore().isEmpty)
    }

    @Test("A file cannot be granted as a folder")
    func fileIsRejected() async throws {
        let file = try storage.write("not-a-folder.txt")
        await #expect(throws: FolderAccessError.notAFolder(file.path)) {
            try await access().grant(file)
        }
    }

    @Test("Protected folders cannot be granted", arguments: ["/", "/System", "/Library"])
    func protectedIsRejected(path: String) async throws {
        await #expect(throws: FolderAccessError.protectedPath(path)) {
            try await FolderAccess(store: store).grant(URL(fileURLWithPath: path, isDirectory: true))
        }
        #expect(try store.load().isEmpty)
    }

    @Test("Folders inside protected locations cannot be granted (temp folders live in /private/var)")
    func insideProtected() async throws {
        await #expect(throws: FolderAccessError.protectedPath(storage.url.path)) {
            try await FolderAccess(store: store).grant(storage.url)
        }
    }

    @Test("A symlinked path into a protected folder cannot be granted (/tmp → /private/tmp)")
    func symlinkIntoProtected() async throws {
        let link = URL(fileURLWithPath: "/tmp", isDirectory: true)
        await #expect(throws: FolderAccessError.protectedPath(link.path)) {
            try await FolderAccess(store: store).grant(link)
        }
    }
}
