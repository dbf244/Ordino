import Foundation

public enum FolderMonitorError: Error, Sendable, Equatable {
    case alreadyStarted
    case couldNotStart(String)
}

public struct FolderMonitorConfiguration: Sendable, Equatable {
    /// How long FSEvents gathers events before delivering a batch.
    public var latency: Duration
    public var stability: StabilityConfiguration

    public init(latency: Duration = .milliseconds(200), stability: StabilityConfiguration = .init()) {
        self.latency = latency
        self.stability = stability
    }
}

/// Watches one folder and reports what happens to the items directly inside it.
///
/// The pipeline: `FolderWatcher` (FSEvents) → `EventInterpreter` (what changed)
/// → `StabilityChecker` (wait until finished) → `FolderActivity`.
/// Items that already exist when monitoring starts are not reported until they change.
/// Removals and renames are only reported for items Ordino knows about (present
/// at start, or already reported as ready), so short-lived temporary files that
/// apps create and delete while saving never show up.
public actor FolderMonitor {
    public let folder: URL
    private let configuration: FolderMonitorConfiguration
    private let rootPath: String

    private var watcher: FolderWatcher?
    private var checker: StabilityChecker?
    private var continuation: AsyncStream<FolderActivity>.Continuation?
    private var tasks: [Task<Void, Never>] = []
    /// Paths of items that exist in the folder and that Ordino has seen settle.
    private var known: Set<String> = []

    public init(folder: URL, configuration: FolderMonitorConfiguration = .init()) {
        self.folder = folder
        self.configuration = configuration
        self.rootPath = canonicalPath(folder.path)
    }

    deinit {
        tasks.forEach { $0.cancel() }
        continuation?.finish()
    }

    public func start() async throws -> AsyncStream<FolderActivity> {
        guard watcher == nil else { throw FolderMonitorError.alreadyStarted }

        let watcher = FolderWatcher(folder: URL(fileURLWithPath: rootPath, isDirectory: true), latency: configuration.latency)
        let batches: AsyncStream<[FSEventRecord]>
        do {
            batches = try await watcher.start()
        } catch {
            throw FolderMonitorError.couldNotStart(folder.path)
        }

        let checker = StabilityChecker(configuration: configuration.stability)
        let (activity, continuation) = AsyncStream.makeStream(of: FolderActivity.self)
        self.watcher = watcher
        self.checker = checker
        self.continuation = continuation
        known = Set(directChildren().map(\.path))

        let interpreter = EventInterpreter(rootPath: rootPath)
        tasks.append(Task { [weak self] in
            for await batch in batches {
                let changes = interpreter.interpret(batch) { FileManager.default.fileExists(atPath: $0) }
                await self?.handle(changes)
            }
        })
        tasks.append(Task { [weak self] in
            for await url in checker.readyFiles {
                await self?.ready(url)
            }
        })
        return activity
    }

    /// Stops watching and ends the activity stream.
    public func stop() async {
        await watcher?.stop()
        await checker?.finish()
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        continuation?.finish()
        watcher = nil
        checker = nil
        continuation = nil
    }

    private func handle(_ changes: [WatchChange]) async {
        guard let checker else { return }
        for change in changes {
            switch change {
            case .candidate(let url):
                await checker.submit(url)
            case .removed(let url):
                await checker.forget(url)
                if known.remove(url.path) != nil {
                    emit(.fileRemoved(url))
                }
            case .renamed(let from, let to):
                await checker.forget(from)
                if known.remove(from.path) != nil {
                    emit(.fileRenamed(from: from, to: to))
                }
                await checker.submit(to)
            case .rootChanged:
                if !FileManager.default.fileExists(atPath: rootPath) {
                    emit(.folderUnavailable(folder))
                }
            case .rescan:
                for url in directChildren() {
                    await checker.submit(url)
                }
            }
        }
    }

    private func ready(_ url: URL) {
        known.insert(url.path)
        emit(.fileReady(url))
    }

    private func emit(_ activity: FolderActivity) {
        continuation?.yield(activity)
    }

    private func directChildren() -> [URL] {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: rootPath, isDirectory: true),
            includingPropertiesForKeys: nil
        )
        return (contents ?? []).filter { !FileFilter.isIgnored($0) }
    }
}

/// The path with symlinks resolved (`/var` → `/private/var`), matching what FSEvents reports.
func canonicalPath(_ path: String) -> String {
    guard let resolved = realpath(path, nil) else { return path }
    defer { free(resolved) }
    return String(cString: resolved)
}
