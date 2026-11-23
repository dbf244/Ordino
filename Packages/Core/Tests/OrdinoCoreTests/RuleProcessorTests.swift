import Foundation
import OrdinoCore
import Testing

@Suite("RuleProcessor")
struct RuleProcessorTests {
    let watched: TemporaryFolder
    let destination: TemporaryFolder
    let destinationID = UUID()

    init() throws {
        watched = try TemporaryFolder()
        destination = try TemporaryFolder()
    }

    func pdfRule(to folderID: UUID) -> Rule {
        Rule(
            name: "PDFs",
            isEnabled: true,
            conditions: ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
            ]),
            actions: [.move(to: FolderReference(folderID: folderID, displayPath: "Destination"))],
            continuesToNextRule: false
        )
    }

    func processor() -> RuleProcessor {
        let destinationURL = destination.url
        let id = destinationID
        return RuleProcessor { $0 == id ? destinationURL : nil }
    }

    @Test("A matching file is moved and the move is reported with where it went")
    func movesMatchingFile() async throws {
        let file = try watched.write("test.pdf")
        let activity = await processor().process(file, rules: [pdfRule(to: destinationID)])
        let expected = destination.url.appendingPathComponent("test.pdf")
        #expect(activity == [.fileMoved(from: file, to: expected, rule: "PDFs")])
        #expect(FileManager.default.fileExists(atPath: expected.path))
    }

    @Test("A file no rule matches is left alone")
    func leavesOthers() async throws {
        let file = try watched.write("notes.txt")
        let activity = await processor().process(file, rules: [pdfRule(to: destinationID)])
        #expect(activity.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("An unavailable destination is reported and the file stays put")
    func unavailableDestination() async throws {
        let file = try watched.write("test.pdf")
        let activity = await processor().process(file, rules: [pdfRule(to: UUID())])
        guard case .actionFailed(let url, let rule, _) = activity.first else {
            Issue.record("Expected a failure, got \(activity)")
            return
        }
        #expect(url == file)
        #expect(rule == "PDFs")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("After a move, later actions and rules apply to the file's new location")
    func followsTheFile() async throws {
        let second = try TemporaryFolder()
        let secondID = UUID()
        let destinationURL = destination.url
        let firstID = destinationID
        let processor = RuleProcessor { id in
            switch id {
            case firstID: destinationURL
            case secondID: second.url
            default: nil
            }
        }
        var rule = pdfRule(to: destinationID)
        rule.actions.append(.move(to: FolderReference(folderID: secondID, displayPath: "Second")))
        let file = try watched.write("test.pdf")

        let activity = await processor.process(file, rules: [rule])

        let middle = destination.url.appendingPathComponent("test.pdf")
        let final = second.url.appendingPathComponent("test.pdf")
        #expect(activity == [
            .fileMoved(from: file, to: middle, rule: "PDFs"),
            .fileMoved(from: middle, to: final, rule: "PDFs"),
        ])
    }

    @Test("A failing action stops the rest of the chain")
    func failureStopsChain() async throws {
        var rule = pdfRule(to: UUID())  // unavailable
        rule.actions.append(.move(to: FolderReference(folderID: destinationID, displayPath: "Destination")))
        let file = try watched.write("test.pdf")

        let activity = await processor().process(file, rules: [rule])

        #expect(activity.count == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A file that disappeared before its rule ran is skipped quietly")
    func vanished() async throws {
        let ghost = watched.url.appendingPathComponent("ghost.pdf")
        #expect(await processor().process(ghost, rules: [pdfRule(to: destinationID)]).isEmpty)
    }
}
