import Foundation
import OrdinoCore
import Testing

/// End to end: a real watched folder, a real rule, a real move.
@Suite("FolderAutomation", .serialized)
struct FolderAutomationTests {
    let watched: TemporaryFolder
    let destination: URL
    let destinationID = UUID()
    let configuration = FolderMonitorConfiguration(
        latency: .milliseconds(100),
        stability: StabilityConfiguration(pollInterval: .milliseconds(100), quietPeriod: .milliseconds(500))
    )

    init() throws {
        watched = try TemporaryFolder()
        destination = try watched.makeFolder("Destination")
    }

    var pdfRule: Rule {
        Rule(
            name: "PDFs",
            isEnabled: true,
            conditions: ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
            ]),
            actions: [.move(to: FolderReference(folderID: destinationID, displayPath: "Destination"))],
            continuesToNextRule: false
        )
    }

    func start(rules: [Rule]) async throws -> (FolderAutomation, StreamRecorder<FolderActivity>) {
        // Let FSEvents deliver the setup (creating Destination) before watching starts.
        try await Task.sleep(for: .milliseconds(500))
        let destination = destination
        let id = destinationID
        let automation = FolderAutomation(
            folder: watched.url,
            rules: rules,
            configuration: configuration,
            resolveFolder: { $0 == id ? destination : nil }
        )
        let recorder = StreamRecorder(try await automation.start())
        try await Task.sleep(for: .milliseconds(300))
        return (automation, recorder)
    }

    @Test("Dropping test.pdf moves it to the destination")
    func dropMoves() async throws {
        let (automation, recorder) = try await start(rules: [pdfRule])
        let file = try watched.write("test.pdf")
        let target = destination.appendingPathComponent("test.pdf")

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileMoved(from: file, to: target, rule: "PDFs")) })
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect(!FileManager.default.fileExists(atPath: file.path))

        // The move must not show up as a removal, and the destination folder
        // changing must not show up as activity either.
        let all = await recorder.settle(for: .seconds(1))
        #expect(all == [.fileReady(file), .fileMoved(from: file, to: target, rule: "PDFs")], "Got: \(all)")
        await automation.stop()
    }

    @Test("A second test.pdf becomes test 2.pdf and nothing is overwritten")
    func conflict() async throws {
        let existing = destination.appendingPathComponent("test.pdf")
        try Data("original".utf8).write(to: existing)
        let (automation, recorder) = try await start(rules: [pdfRule])

        let file = try watched.write("test.pdf", bytes: 100)
        let renamed = destination.appendingPathComponent("test 2.pdf")

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileMoved(from: file, to: renamed, rule: "PDFs")) })
        #expect(try String(contentsOf: existing, encoding: .utf8) == "original")
        #expect(try Data(contentsOf: renamed).count == 100)
        await automation.stop()
    }

    @Test("Files no rule matches stay where they are")
    func nonMatching() async throws {
        let (automation, recorder) = try await start(rules: [pdfRule])
        let file = try watched.write("notes.txt")

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileReady(file)) })
        let all = await recorder.settle(for: .seconds(1))
        #expect(all == [.fileReady(file)], "Got: \(all)")
        #expect(FileManager.default.fileExists(atPath: file.path))
        await automation.stop()
    }

    @Test("Deleting a file Ordino did not move is still reported")
    func userDeletion() async throws {
        let file = try watched.write("keep.txt")
        let (automation, recorder) = try await start(rules: [pdfRule])

        try FileManager.default.removeItem(at: file)

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileRemoved(file)) })
        await automation.stop()
    }

    @Test("Rules can be replaced while watching")
    func updateRules() async throws {
        let (automation, recorder) = try await start(rules: [])
        let first = try watched.write("first.pdf")
        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileReady(first)) })
        #expect(FileManager.default.fileExists(atPath: first.path))

        await automation.updateRules([pdfRule])
        let second = try watched.write("second.pdf")
        let target = destination.appendingPathComponent("second.pdf")

        #expect(await recorder.wait(timeout: .seconds(3)) { $0.contains(.fileMoved(from: second, to: target, rule: "PDFs")) })
        await automation.stop()
    }
}
