import Foundation

/// Collects everything an `AsyncStream` emits so tests can wait for and
/// inspect it without racing the producer.
actor StreamRecorder<Element: Sendable> {
    private(set) var items: [Element] = []

    init(_ stream: AsyncStream<Element>) {
        Task { await self.consume(stream) }
    }

    private func consume(_ stream: AsyncStream<Element>) async {
        for await item in stream {
            items.append(item)
        }
    }

    /// Waits until `condition` holds for the recorded items, or `timeout` passes.
    /// Returns whether the condition was met.
    func wait(
        timeout: Duration = .seconds(5),
        until condition: @Sendable ([Element]) -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if condition(items) { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition(items)
    }

    /// Waits for `duration` and returns everything recorded so far.
    func settle(for duration: Duration) async -> [Element] {
        try? await Task.sleep(for: duration)
        return items
    }
}
