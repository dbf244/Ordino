import Foundation

public struct StabilityConfiguration: Sendable, Equatable {
    /// How often pending files are measured.
    public var pollInterval: Duration
    /// How long an item must stay unchanged before it counts as finished.
    public var quietPeriod: Duration

    public init(pollInterval: Duration = .milliseconds(250), quietPeriod: Duration = .seconds(1)) {
        self.pollInterval = pollInterval
        self.quietPeriod = quietPeriod
    }
}

/// Reports an item only once it has stopped changing, so Ordino never acts
/// on a file that is still being written, copied or downloaded.
///
/// Files are measured (size and modification date) every `pollInterval`; a
/// file whose signature stays the same for `quietPeriod` is reported on
/// `readyFiles`.
///
/// Folders are expensive to measure, since that means walking everything
/// inside, so they are walked as little as possible: once when they arrive,
/// then only after `quietPeriod` has passed both since the last walk and since
/// the last sign of activity inside them (`touch`, fed by FSEvents). A folder
/// counts as finished when two walks at least `quietPeriod` apart agree. While
/// a big folder is being copied the events keep it waiting without any walks;
/// if events are lost, the spaced walks still catch the change.
///
/// An item is not reported again unless it actually changed. Partial downloads
/// and hidden files are ignored. Polling only runs while something is pending,
/// so an idle checker costs nothing.
public actor StabilityChecker {
    public nonisolated let readyFiles: AsyncStream<URL>
    private let continuation: AsyncStream<URL>.Continuation
    private let configuration: StabilityConfiguration
    private let readSignature: @Sendable (URL) -> FileSignature?

    private struct Pending {
        let url: URL
        var signature: FileSignature
        /// Files: when the signature last changed. Folders: when they were last walked.
        var measuredAt: ContinuousClock.Instant
        /// Folders: the last sign that something inside them changed.
        var lastActivity: ContinuousClock.Instant
    }

    private var pending: [String: Pending] = [:]
    private var reported: [String: FileSignature] = [:]
    private var poller: Task<Void, Never>?

    public init(configuration: StabilityConfiguration = .init()) {
        self.init(configuration: configuration, readSignature: FileSignature.read)
    }

    init(configuration: StabilityConfiguration, readSignature: @escaping @Sendable (URL) -> FileSignature?) {
        self.configuration = configuration
        self.readSignature = readSignature
        (readyFiles, continuation) = AsyncStream.makeStream(of: URL.self)
    }

    deinit {
        poller?.cancel()
        continuation.finish()
    }

    /// Whether the checker is currently measuring pending items.
    public var isPolling: Bool {
        poller != nil
    }

    /// Something happened to `url`; report it once it has stopped changing.
    public func submit(_ url: URL) {
        guard !FileFilter.isIgnored(url) else { return }
        let now = ContinuousClock.now
        if pending[url.path]?.signature.isDirectory == true {
            // Already followed: walking it again now would only cost time.
            pending[url.path]?.lastActivity = now
            return
        }
        guard let signature = readSignature(url) else {
            pending.removeValue(forKey: url.path)
            return
        }
        pending[url.path] = Pending(url: url, signature: signature, measuredAt: now, lastActivity: now)
        startPollingIfNeeded()
    }

    /// Something changed somewhere inside the folder at `url`. If that folder
    /// is waiting to settle, it keeps waiting; otherwise nothing happens.
    public func touch(_ url: URL) {
        guard pending[url.path]?.signature.isDirectory == true else { return }
        pending[url.path]?.lastActivity = .now
    }

    /// `url` is gone (deleted or renamed away). Stop tracking it, so that an
    /// item that later appears at the same path is reported as new.
    public func forget(_ url: URL) {
        pending.removeValue(forKey: url.path)
        reported.removeValue(forKey: url.path)
    }

    /// Ends `readyFiles` and stops polling.
    public func finish() {
        poller?.cancel()
        poller = nil
        pending.removeAll()
        continuation.finish()
    }

    private func startPollingIfNeeded() {
        guard poller == nil else { return }
        // Background bookkeeping: on Apple silicon it can run on the efficiency cores.
        poller = Task(priority: .utility) { [weak self] in
            await self?.poll()
        }
    }

    private func poll() async {
        let interval = configuration.pollInterval
        while !pending.isEmpty, !Task.isCancelled {
            // The tolerance lets macOS line this wake-up up with others.
            try? await Task.sleep(for: interval, tolerance: interval / 5)
            guard !Task.isCancelled else { break }
            measurePending()
        }
        poller = nil
    }

    private func measurePending() {
        let now = ContinuousClock.now
        let quiet = configuration.quietPeriod
        for (path, item) in pending {
            if item.signature.isDirectory {
                // Recent activity inside, or walked too recently: nothing to learn yet.
                guard now - item.lastActivity >= quiet, now - item.measuredAt >= quiet else { continue }
            }
            guard let signature = readSignature(item.url) else {
                pending.removeValue(forKey: path)
                continue
            }
            if signature != item.signature {
                pending[path]?.signature = signature
                pending[path]?.measuredAt = now
            } else if item.signature.isDirectory || now - item.measuredAt >= quiet {
                pending.removeValue(forKey: path)
                if reported[path] != signature {
                    reported[path] = signature
                    continuation.yield(item.url)
                }
            }
        }
    }
}
