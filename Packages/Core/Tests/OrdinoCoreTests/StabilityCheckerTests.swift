import Foundation
import OrdinoCore
import Testing

/// Uses real files with short timings so the suite stays fast.
@Suite("StabilityChecker")
struct StabilityCheckerTests {
    let folder: TemporaryFolder
    let configuration = StabilityConfiguration(pollInterval: .milliseconds(50), quietPeriod: .milliseconds(300))

    init() throws {
        folder = try TemporaryFolder()
    }

    func names(_ urls: [URL]) -> [String] {
        urls.map(\.lastPathComponent)
    }

    @Test("A finished file is reported once")
    func finishedFileReportedOnce() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let file = try folder.write("invoice.pdf")

        await checker.submit(file)
        await checker.submit(file)

        #expect(await recorder.wait { $0.count == 1 })
        #expect(names(await recorder.settle(for: .milliseconds(600))) == ["invoice.pdf"])
    }

    @Test("A file is not reported before the quiet period has passed")
    func waitsForQuietPeriod() async throws {
        let checker = StabilityChecker(configuration: StabilityConfiguration(pollInterval: .milliseconds(50), quietPeriod: .seconds(1)))
        let recorder = StreamRecorder(checker.readyFiles)
        let file = try folder.write("quiet.txt")

        await checker.submit(file)

        #expect(await recorder.settle(for: .milliseconds(500)).isEmpty)
        #expect(await recorder.wait { $0.count == 1 })
    }

    @Test("A file that is still being written is reported once, only when it's finished")
    func growingFile() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let name = "big.mov"
        let file = folder.url.appendingPathComponent(name)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        await checker.submit(file)

        // 12 chunks, 100 ms apart: 1.2 s of writing, much longer than the quiet period.
        let writer = Task { try await folder.writeSlowly(name, chunks: 12, chunkSize: 64 * 1024, pause: .milliseconds(100)) }
        // The writer appends to the same file; keep telling the checker about it.
        for _ in 0..<12 {
            try await Task.sleep(for: .milliseconds(100))
            #expect(await recorder.items.isEmpty, "Reported while the file was still growing")
            await checker.submit(file)
        }
        _ = try await writer.value

        #expect(await recorder.wait { $0.count == 1 })
        #expect(names(await recorder.settle(for: .milliseconds(600))) == [name])
        let size = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int
        #expect(size == 12 * 64 * 1024)
    }

    @Test("Partial downloads are never reported", arguments: ["video.mp4.crdownload", "Report.pdf.download", "file.part"])
    func partialDownloads(name: String) async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        await checker.submit(try folder.write(name))
        #expect(await recorder.settle(for: .milliseconds(700)).isEmpty)
    }

    @Test("A file deleted while waiting is not reported")
    func deletedWhileWaiting() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let file = try folder.write("temp.txt")
        await checker.submit(file)
        try FileManager.default.removeItem(at: file)
        #expect(await recorder.settle(for: .milliseconds(700)).isEmpty)
    }

    @Test("An unchanged file is not reported again; a changed one is")
    func reportsOnlyRealChanges() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let file = try folder.write("notes.txt", bytes: 10)

        await checker.submit(file)
        #expect(await recorder.wait { $0.count == 1 })

        await checker.submit(file)
        #expect(await recorder.settle(for: .milliseconds(600)).count == 1)

        try Data(repeating: 1, count: 20).write(to: file)
        await checker.submit(file)
        #expect(await recorder.wait { $0.count == 2 })
    }

    @Test("A forgotten file is reported again when it comes back")
    func forgetAllowsReportingAgain() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let file = try folder.write("again.txt")

        await checker.submit(file)
        #expect(await recorder.wait { $0.count == 1 })

        await checker.forget(file)
        await checker.submit(file)
        #expect(await recorder.wait { $0.count == 2 })
    }

    @Test("A folder being filled is reported once it stops changing")
    func folderBeingFilled() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        let sub = try folder.makeFolder("Album")
        await checker.submit(sub)

        for index in 0..<6 {
            try Data(repeating: 0, count: 1024).write(to: sub.appendingPathComponent("photo\(index).jpg"))
            try await Task.sleep(for: .milliseconds(100))
            #expect(await recorder.items.isEmpty, "Reported while the folder was still being filled")
        }

        #expect(await recorder.wait { $0.count == 1 })
        #expect(names(await recorder.items) == ["Album"])
    }

    @Test("The checker does no work once nothing is pending")
    func idleWhenNothingPending() async throws {
        let checker = StabilityChecker(configuration: configuration)
        let recorder = StreamRecorder(checker.readyFiles)
        await checker.submit(try folder.write("one.txt"))
        #expect(await recorder.wait { $0.count == 1 })
        #expect(await checker.isPolling == false)
    }
}
