import Foundation

public struct StabilityConfiguration: Sendable, Equatable {
    /// How often pending items are measured.
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
/// Each submitted item is measured (size, modification date, and for folders
/// their contents) every `pollInterval`. When its signature stays the same for
/// `quietPeriod`, it is reported on `readyFiles`. An item is not reported again
/// unless it actually changed. Partial downloads and hidden files are ignored.
/// Polling only runs while something is pending, so an idle checker costs nothing.
public actor StabilityChecker {
    public nonisolated let readyFiles: AsyncStream<URL>
    private let continuation: AsyncStream<URL>.Continuation
    private let configuration: StabilityConfiguration

    private struct Pending {
        let url: URL
        var signature: FileSignature
        var unchangedSince: ContinuousClock.Instant
    }

    private var pending: [String: Pending] = [:]
    private var reported: [String: FileSignature] = [:]
    private var poller: Task<Void, Never>?

    public init(configuration: StabilityConfiguration = .init()) {
        self.configuration = configuration
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
        guard let signature = FileSignature.read(url) else {
            pending.removeValue(forKey: url.path)
            return
        }
        pending[url.path] = Pending(url: url, signature: signature, unchangedSince: .now)
        startPollingIfNeeded()
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
        poller = Task { [weak self] in
            await self?.poll()
        }
    }

    private func poll() async {
        while !pending.isEmpty, !Task.isCancelled {
            try? await Task.sleep(for: configuration.pollInterval)
            guard !Task.isCancelled else { break }
            measurePending()
        }
        poller = nil
    }

    private func measurePending() {
        let now = ContinuousClock.now
        for (path, item) in pending {
            let url = item.url
            guard let signature = FileSignature.read(url) else {
                pending.removeValue(forKey: path)
                continue
            }
            if signature != item.signature {
                pending[path] = Pending(url: url, signature: signature, unchangedSince: now)
            } else if now - item.unchangedSince >= configuration.quietPeriod {
                pending.removeValue(forKey: path)
                if reported[path] != signature {
                    reported[path] = signature
                    continuation.yield(url)
                }
            }
        }
    }
}
