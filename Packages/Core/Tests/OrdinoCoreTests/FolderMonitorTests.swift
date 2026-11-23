import Foundation
import OrdinoCore
import Testing

/// End to end on a real temp folder: FSEvents → interpreter → stability → activity.
/// Serialized because FSEvents is a shared system service and timing matters.
@Suite("FolderMonitor", .serialized)
struct FolderMonitorTests {
    let folder: TemporaryFolder
    let configuration = FolderMonitorConfiguration(
        latency: .milliseconds(100),
        stability: StabilityConfiguration(pollInterval: .milliseconds(100), quietPeriod: .milliseconds(500))
    )

    init() throws {
        folder = try TemporaryFolder()
    }

    func start() async throws -> (FolderMonitor, StreamRecorder<FolderActivity>) {
        let monitor = FolderMonitor(folder: folder.url, configuration: configuration)
        let recorder = StreamRecorder(try await monitor.start())
        // Give FSEvents a moment to begin, so earlier test setup is not reported.
        try await Task.sleep(for: .milliseconds(300))
        return (monitor, recorder)
    }

    func ready(_ name: String) -> FolderActivity {
        .fileReady(folder.url.appendingPathComponent(name))
    }

    @Test("A new file is reported in under 2 seconds")
    func newFileIsFast() async throws {
        let (monitor, recorder) = try await start()
        let expected = ready("fresh.pdf")
        let start = ContinuousClock.now
        try folder.write("fresh.pdf")

        #expect(await recorder.wait(timeout: .seconds(2)) { $0.contains(expected) })
        #expect(ContinuousClock.now - start < .seconds(2))
        await monitor.stop()
    }

    @Test("A deleted file is reported as removed")
    func deletedFile() async throws {
        let file = try folder.write("old.txt")
        let (monitor, recorder) = try await start()

        try FileManager.default.removeItem(at: file)

        #expect(await recorder.wait(timeout: .seconds(2)) { $0.contains(.fileRemoved(file)) })
        await monitor.stop()
    }

    @Test("A renamed file is reported as renamed, then as ready under its new name")
    func renamedFile() async throws {
        let file = try folder.write("draft.txt")
        let (monitor, recorder) = try await start()
        let renamed = folder.url.appendingPathComponent("final.txt")

        try FileManager.default.moveItem(at: file, to: renamed)

        #expect(await recorder.wait(timeout: .seconds(3)) {
            $0.contains(.fileRenamed(from: file, to: renamed)) && $0.contains(.fileReady(renamed))
        })
        await monitor.stop()
    }

    @Test("A large file being copied is reported once, only when it's finished")
    func largeCopy() async throws {
        let (monitor, recorder) = try await start()

        // 2 s of writing in 20 chunks, far longer than the 0.5 s quiet period would need
        // if the watcher did not keep pushing the file back to "not ready".
        let file = try await folder.writeSlowly("movie.mov", chunks: 20, chunkSize: 256 * 1024, pause: .milliseconds(100))
        let earlyReports = await recorder.items.filter { $0 == .fileReady(file) }
        #expect(earlyReports.isEmpty, "Reported before the copy finished")

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileReady(file)) })
        let all = await recorder.settle(for: .seconds(1))
        #expect(all.filter { $0 == .fileReady(file) }.count == 1)
        await monitor.stop()
    }

    @Test("A download that finishes by renaming .crdownload is reported once under its final name")
    func browserDownload() async throws {
        let (monitor, recorder) = try await start()

        let partial = try await folder.writeSlowly("song.mp3.crdownload", chunks: 5, chunkSize: 32 * 1024, pause: .milliseconds(100))
        let final = folder.url.appendingPathComponent("song.mp3")
        try FileManager.default.moveItem(at: partial, to: final)

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileReady(final)) })
        let all = await recorder.settle(for: .seconds(1))
        #expect(all == [.fileReady(final)], "Got: \(all)")
        await monitor.stop()
    }

    @Test("A temporary file created and deleted before it settles is not reported")
    func transientFile() async throws {
        let (monitor, recorder) = try await start()

        let temp = try folder.write("~save.tmp")
        try await Task.sleep(for: .milliseconds(150))
        try FileManager.default.removeItem(at: temp)

        #expect(await recorder.settle(for: .seconds(2)).isEmpty)
        await monitor.stop()
    }

    @Test("Files inside subfolders are not reported")
    func subfolderContents() async throws {
        let sub = try folder.makeFolder("Inside")
        let (monitor, recorder) = try await start()

        try Data([1, 2, 3]).write(to: sub.appendingPathComponent("deep.txt"))

        let all = await recorder.settle(for: .seconds(2))
        #expect(!all.contains(.fileReady(sub.appendingPathComponent("deep.txt"))))
        await monitor.stop()
    }

    @Test("Deleting the watched folder is reported")
    func watchedFolderDeleted() async throws {
        let parent = try TemporaryFolder()
        let watched = try parent.makeFolder("Watched")
        let monitor = FolderMonitor(folder: watched, configuration: configuration)
        let recorder = StreamRecorder(try await monitor.start())
        try await Task.sleep(for: .milliseconds(300))

        try FileManager.default.removeItem(at: watched)

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.folderUnavailable(watched)) })
        await monitor.stop()
    }

    @Test("Stopping ends the activity stream")
    func stopEndsStream() async throws {
        let monitor = FolderMonitor(folder: folder.url, configuration: configuration)
        let stream = try await monitor.start()
        await monitor.stop()
        var count = 0
        for await _ in stream { count += 1 }
        #expect(count == 0)
    }

    @Test("Starting twice is an error")
    func startTwice() async throws {
        let monitor = FolderMonitor(folder: folder.url, configuration: configuration)
        _ = try await monitor.start()
        await #expect(throws: FolderMonitorError.alreadyStarted) {
            _ = try await monitor.start()
        }
        await monitor.stop()
    }
}
