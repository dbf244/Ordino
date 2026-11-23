import Foundation

/// A watched folder with its rules, running: the journey of a file from
/// "it landed here" to "its rule ran".
///
/// `FolderMonitor` reports files once they settle; each ready file goes
/// through `RuleProcessor`. Files Ordino moves away itself are not reported
/// as removed: the move is reported instead.
public actor FolderAutomation {
    public let folder: URL
    private var rules: [Rule]
    private let monitor: FolderMonitor
    private let processor: RuleProcessor
    private var continuation: AsyncStream<FolderActivity>.Continuation?
    private var task: Task<Void, Never>?

    public init(
        folder: URL,
        rules: [Rule],
        configuration: FolderMonitorConfiguration = .init(),
        resolveFolder: @escaping @Sendable (UUID) async -> URL?
    ) {
        self.folder = folder
        self.rules = rules
        self.monitor = FolderMonitor(folder: folder, configuration: configuration)
        self.processor = RuleProcessor(resolveFolder: resolveFolder)
    }

    deinit {
        task?.cancel()
        continuation?.finish()
    }

    public func start() async throws -> AsyncStream<FolderActivity> {
        let activity = try await monitor.start()
        let (stream, continuation) = AsyncStream.makeStream(of: FolderActivity.self)
        self.continuation = continuation
        task = Task(priority: .utility) { [weak self] in
            for await item in activity {
                await self?.handle(item)
            }
            await self?.finish()
        }
        return stream
    }

    /// Replaces the rules. Files that become ready from now on use the new rules.
    public func updateRules(_ rules: [Rule]) {
        self.rules = rules
    }

    public func stop() async {
        await monitor.stop()
        task?.cancel()
        task = nil
        finish()
    }

    private func finish() {
        continuation?.finish()
        continuation = nil
    }

    private func handle(_ activity: FolderActivity) async {
        continuation?.yield(activity)
        guard case .fileReady(let url) = activity, !rules.isEmpty else { return }

        // The file may be about to leave; don't report that as a removal.
        await monitor.stopTracking(url)
        let results = await processor.process(url, rules: rules)
        if FileManager.default.fileExists(atPath: url.path) {
            await monitor.track(url)
        }
        for result in results {
            continuation?.yield(result)
        }
    }
}
