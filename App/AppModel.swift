import Foundation
import Observation
import OrdinoCore
import os

/// The app's state: which folder is watched and what happened in it.
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

    @ObservationIgnored private let access: FolderAccess?
    @ObservationIgnored private var watchedID: UUID?
    @ObservationIgnored private var monitor: FolderMonitor?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(subsystem: "io.github.dbf244.Ordino", category: "activity")

    init() {
        do {
            access = FolderAccess(store: try JSONFolderStore.applicationSupport())
        } catch {
            access = nil
            folderState = .failed(String(localized: "Ordino can't save its settings."))
        }
    }

    /// Restores the folder chosen in an earlier launch, if any.
    func start() async {
        guard let access else { return }
        guard let folder = await access.restore().first else { return }
        watchedID = folder.id
        switch folder.availability {
        case .available(let url):
            await watch(url)
        case .unavailable(let error):
            logger.error("Saved folder is unavailable: \(String(describing: error), privacy: .public)")
            folderState = .needsAccess(path: folder.path)
        }
    }

    /// Asks the user for a folder and starts watching it instead of the current one.
    func chooseFolder() async {
        guard let access else { return }
        let suggestion: URL? = switch folderState {
        case .watching(let url): url
        case .needsAccess(let path): URL(fileURLWithPath: path, isDirectory: true)
        case .none, .failed: nil
        }
        guard let url = FolderPicker.chooseFolder(startingAt: suggestion) else {
            logger.notice("Folder picker cancelled")
            return
        }
        logger.notice("Folder chosen in the picker")

        do {
            let granted = try await access.grant(url)
            if let previous = watchedID, previous != granted.id {
                try? await access.revoke(previous)
            }
            watchedID = granted.id
            logger.notice("Folder access granted and saved")
            await watch(URL(fileURLWithPath: granted.path, isDirectory: true))
        } catch FolderAccessError.protectedPath {
            FolderPicker.explainProtected(url)
        } catch {
            logger.error("Could not grant access: \(String(describing: error), privacy: .public)")
            FolderPicker.explainFailure(url)
        }
    }

    private func watch(_ url: URL) async {
        await stopWatching()
        let monitor = FolderMonitor(folder: url)
        do {
            let activity = try await monitor.start()
            self.monitor = monitor
            folderState = .watching(url)
            logger.notice("Watching folder")
            monitorTask = Task { [weak self] in
                for await item in activity {
                    self?.record(item)
                }
            }
        } catch {
            logger.error("Could not watch folder: \(String(describing: error), privacy: .public)")
            folderState = .needsAccess(path: url.path)
        }
    }

    private func stopWatching() async {
        monitorTask?.cancel()
        monitorTask = nil
        await monitor?.stop()
        monitor = nil
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
        case .folderUnavailable(let url):
            logger.error("Watched folder is unavailable")
            folderState = .needsAccess(path: url.path)
            Task { await stopWatching() }
        }
    }
}
