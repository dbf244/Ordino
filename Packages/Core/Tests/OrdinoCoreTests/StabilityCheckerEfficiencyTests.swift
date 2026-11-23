import Foundation
@testable import OrdinoCore
import os
import Testing

/// Counts how often folders are walked, to keep the cost of settling a big
/// folder independent of how long it takes to copy.
private final class WalkCounter: Sendable {
    private let walks = OSAllocatedUnfairLock(initialState: 0)

    var count: Int { walks.withLock { $0 } }

    func read(_ url: URL) -> FileSignature? {
        let signature = FileSignature.read(url)
        if signature?.isDirectory == true {
            walks.withLock { $0 += 1 }
        }
        return signature
    }
}

@Suite("StabilityChecker efficiency")
struct StabilityCheckerEfficiencyTests {
    let folder: TemporaryFolder
    let configuration = StabilityConfiguration(pollInterval: .milliseconds(50), quietPeriod: .milliseconds(300))

    init() throws {
        folder = try TemporaryFolder()
    }

    @Test("A folder being filled is not walked again while events say it is still changing")
    func eventsAvoidWalks() async throws {
        let counter = WalkCounter()
        let checker = StabilityChecker(configuration: configuration, readSignature: counter.read)
        let recorder = StreamRecorder(checker.readyFiles)
        let album = try folder.makeFolder("Album")
        await checker.submit(album)

        // 1.2 s of copying, with FSEvents reporting each new file inside.
        for index in 0..<12 {
            try Data(repeating: 0, count: 1024).write(to: album.appendingPathComponent("photo\(index).jpg"))
            await checker.touch(album)
            if index % 4 == 0 {
                await checker.submit(album)  // the folder's own event, now and then
            }
            try await Task.sleep(for: .milliseconds(100))
            #expect(await recorder.items.isEmpty, "Reported while the folder was still being filled")
        }

        #expect(await recorder.wait { $0.count == 1 })
        // One walk when it arrives and at most two once it goes quiet (one more of
        // slack for a slow machine). Polling every 50 ms walked it about 30 times.
        #expect(counter.count <= 4, "Walked \(counter.count) times")
        #expect(await recorder.settle(for: .milliseconds(600)).count == 1)
    }

    @Test("A folder that changes without any events is still not reported early")
    func noEventsStillSafe() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let album = try folder.makeFolder("Album")
        let file = album.appendingPathComponent("movie.mov")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        await checker.submit(album)

        // A file inside keeps growing, but nobody calls `touch`.
        let handle = try FileHandle(forWritingTo: file)
        for _ in 0..<12 {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(repeating: 1, count: 32 * 1024))
            try await Task.sleep(for: .milliseconds(100))
            #expect(await recorder.items.isEmpty, "Reported while a file inside was still growing")
        }
        try handle.close()

        #expect(await recorder.wait { $0.count == 1 })
    }

    @Test("Activity inside a folder that is not pending does nothing")
    func touchUnknownFolder() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let album = try folder.makeFolder("Album")
        await checker.touch(album)
        #expect(await recorder.settle(for: .milliseconds(600)).isEmpty)
        #expect(await checker.isPolling == false)
    }

    @Test("A file is still measured on every poll and reported on time")
    func filesStillPolled() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let started = ContinuousClock.now
        await checker.submit(try folder.write("invoice.pdf"))
        #expect(await recorder.wait { $0.count == 1 })
        // quiet period plus at most a couple of polls (with timer tolerance)
        #expect(ContinuousClock.now - started < .milliseconds(900))
    }
}
