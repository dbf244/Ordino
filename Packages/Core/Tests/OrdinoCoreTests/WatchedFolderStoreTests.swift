import Foundation
import OrdinoCore
import Testing

@Suite("WatchedFolderStore")
struct WatchedFolderStoreTests {
    let storage: TemporaryFolder
    let store: JSONWatchedFolderStore

    init() throws {
        storage = try TemporaryFolder()
        store = JSONWatchedFolderStore(fileURL: storage.url.appendingPathComponent("watched.json"))
    }

    @Test("An empty store loads as no watched folders")
    func empty() throws {
        #expect(try store.load().isEmpty)
    }

    @Test("Watched folders round-trip")
    func roundTrip() throws {
        let folders = [WatchedFolder(id: UUID(), folderID: UUID(), rules: [])]
        try store.save(folders)
        #expect(try store.load() == folders)
    }

    @Test("A v0.1.0 install (one granted folder, no watched list) becomes that folder watched")
    func migratesFromFirstRelease() {
        let granted = UUID()
        let migrated = WatchedFolder.migrated(watched: [], grantedFolderIDs: [granted])
        #expect(migrated.map(\.folderID) == [granted])
        #expect(migrated.first?.rules.isEmpty == true)
    }

    @Test("Migration leaves an existing watched list alone")
    func noMigrationWhenConfigured() {
        let existing = [WatchedFolder(id: UUID(), folderID: UUID(), rules: [])]
        #expect(WatchedFolder.migrated(watched: existing, grantedFolderIDs: [UUID(), UUID()]) == existing)
    }

    @Test("Migration does nothing when it's unclear which folder was watched")
    func noMigrationWhenAmbiguous() {
        #expect(WatchedFolder.migrated(watched: [], grantedFolderIDs: [UUID(), UUID()]).isEmpty)
        #expect(WatchedFolder.migrated(watched: [], grantedFolderIDs: []).isEmpty)
    }
}
