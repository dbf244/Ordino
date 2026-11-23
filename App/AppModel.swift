import Foundation
import Observation
import OrdinoCore
import os

/// The app's state: which folder is watched, its rules, and what happened.
@MainActor
@Observable
final class AppModel {
    enum FolderState: Equatable {
        /// No folder chosen yet.
        case none
        case watching(URL)
        /// A folder was chosen before, but access to it no longer works.
        case needsAccess(path: String)
        /// Something went wrong that the user cannot fix by choosing again.
        case failed(String)
    }

    private(set) var folderState: FolderState = .none
    private(set) var log = ActivityLog()
    /// Where the test rule moves PDFs, if a destination was chosen.
    private(set) var testRuleDestination: FolderReference?

    @ObservationIgnored private let access: FolderAccess?
    @ObservationIgnored private let watchedStore: (any WatchedFolderStore)?
    @ObservationIgnored private var watched: WatchedFolder?
    /// Granted folders that are accessible right now, by `StoredFolder.id`.
    @ObservationIgnored private var availableFolders: [UUID: URL] = [:]
    @ObservationIgnored private var automation: FolderAutomation?
    @ObservationIgnored private var automationTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "io.github.dbf244.Ordino", category: "activity")

    init() {
        let folderStore = try? JSONFolderStore.applicationSupport()
        let watchedFolderStore = try? JSONWatchedFolderStore.applicationSupport()
        if let folderStore, let watchedFolderStore {
            access = FolderAccess(store: folderStore)
            watchedStore = watchedFolderStore
        } else {
            access = nil
            watchedStore = nil
            folderState = .failed(String(localized: "Ordino can't save its settings."))
        }
    }

    // MARK: - Launch

    /// Restores the folders and rules saved in an earlier launch.
    func start() async {
        guard let access, let watchedStore else { return }
        let restored = await access.restore()
        for folder in restored {
            if case .available(let url) = folder.availability {
                availableFolders[folder.id] = url
            }
        }

        let saved: [WatchedFolder]
        do {
            saved = try watchedStore.load()
        } catch {
            logger.error("Could not read watched folders: \(String(describing: error), privacy: .public)")
            folderState = .failed(String(localized: "Ordino can't read its settings."))
            return
        }
        let migrated = WatchedFolder.migrated(watched: saved, grantedFolderIDs: restored.map(\.id))
        if migrated != saved {
            save(migrated)
        }
        guard let current = migrated.first else { return }
        watched = current
        testRuleDestination = TestRule.destination(in: current.rules)

        if let url = availableFolders[current.folderID] {
            await startAutomation(at: url, rules: current.rules)
        } else {
            let path = restored.first { $0.id == current.folderID }?.path ?? ""
            logger.error("Saved watched folder is unavailable")
            folderState = .needsAccess(path: path)
        }
    }

    // MARK: - Choosing folders

    /// Asks the user for a folder and watches it instead of the current one.
    /// The rules move over to the new folder.
    func chooseFolder() async {
        let suggestion: URL? = switch folderState {
        case .watching(let url): url
        case .needsAccess(let path): URL(fileURLWithPath: path, isDirectory: true)
        case .none, .failed: nil
        }
        guard let granted = await pickAndGrant(startingAt: suggestion) else { return }

        let previous = watched?.folderID
        let updated = WatchedFolder(id: watched?.id ?? UUID(), folderID: granted.id, rules: watched?.rules ?? [])
        watched = updated
        save([updated])
        if let previous, previous != granted.id {
            await revokeIfUnused(previous)
        }
        await startAutomation(at: URL(fileURLWithPath: granted.path, isDirectory: true), rules: updated.rules)
    }

    /// Asks the user where the test rule should move PDFs.
    func chooseTestRuleDestination() async {
        guard var current = watched else { return }
        let suggestion = availableFolders[current.folderID]
        guard let granted = await pickAndGrant(startingAt: suggestion) else { return }
        guard granted.id != current.folderID else {
            FolderPicker.explainSameFolder()
            return
        }

        let previous = testRuleDestination?.folderID
        let destination = FolderReference(folderID: granted.id, displayPath: granted.path)
        current.rules = [TestRule.make(destination: destination)]
        watched = current
        testRuleDestination = destination
        save([current])
        if let previous, previous != granted.id {
            await revokeIfUnused(previous)
        }
        await automation?.updateRules(current.rules)
        logger.notice("Test rule destination chosen")
    }

    private func pickAndGrant(startingAt suggestion: URL?) async -> StoredFolder? {
        guard let access else { return nil }
        guard let url = FolderPicker.chooseFolder(startingAt: suggestion) else {
            logger.notice("Folder picker cancelled")
            return nil
        }
        do {
            let granted = try await access.grant(url)
            availableFolders[granted.id] = URL(fileURLWithPath: granted.path, isDirectory: true)
            logger.notice("Folder access granted and saved")
            return granted
        } catch FolderAccessError.protectedPath {
            FolderPicker.explainProtected(url)
        } catch {
            logger.error("Could not grant access: \(String(describing: error), privacy: .public)")
            FolderPicker.explainFailure(url)
        }
        return nil
    }

    /// Gives up access to a folder nothing uses any more.
    private func revokeIfUnused(_ id: UUID) async {
        let inUse = watched?.folderID == id || testRuleDestination?.folderID == id
        guard !inUse else { return }
        availableFolders.removeValue(forKey: id)
        try? await access?.revoke(id)
    }

    private func save(_ folders: [WatchedFolder]) {
        do {
            try watchedStore?.save(folders)
        } catch {
            logger.error("Could not save watched folders: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Running

    private func startAutomation(at url: URL, rules: [Rule]) async {
        await stopAutomation()
        let automation = FolderAutomation(folder: url, rules: rules) { [weak self] id in
            await self?.availableFolders[id]
        }
        do {
            let activity = try await automation.start()
            self.automation = automation
            folderState = .watching(url)
            logger.notice("Watching folder")
            automationTask = Task { [weak self] in
                for await item in activity {
                    self?.record(item)
                }
            }
        } catch {
            logger.error("Could not watch folder: \(String(describing: error), privacy: .public)")
            folderState = .needsAccess(path: url.path)
        }
    }

    private func stopAutomation() async {
        automationTask?.cancel()
        automationTask = nil
        await automation?.stop()
        automation = nil
    }

    private func record(_ activity: FolderActivity) {
        log.record(activity)
        switch activity {
        case .fileReady(let url):
            logger.notice("Ready: \(url.lastPathComponent, privacy: .private)")
        case .fileRemoved(let url):
            logger.notice("Removed: \(url.lastPathComponent, privacy: .private)")
        case .fileRenamed(let from, let to):
            logger.notice("Renamed: \(from.lastPathComponent, privacy: .private) → \(to.lastPathComponent, privacy: .private)")
        case .fileMoved(let from, let to, let rule):
            logger.notice("Moved by rule \(rule, privacy: .private): \(from.path, privacy: .private) → \(to.path, privacy: .private)")
        case .actionFailed(_, let rule, let reason):
            logger.error("Rule \(rule, privacy: .private) failed: \(String(describing: reason), privacy: .public)")
        case .folderUnavailable(let url):
            logger.error("Watched folder is unavailable")
            folderState = .needsAccess(path: url.path)
            Task { await stopAutomation() }
        }
    }
}
