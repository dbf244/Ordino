import Foundation
@testable import Ordino
import OrdinoCore
import Testing

@Suite("Test rule")
struct TestRuleTests {
    let destination = FolderReference(folderID: UUID(), displayPath: "/Users/someone/Ordino-Playground/Destination")

    func facts(_ name: String) -> FileFacts {
        FileFacts(url: URL(fileURLWithPath: "/Users/someone/Ordino-Playground/\(name)"), isDirectory: false)
    }

    @Test("It matches PDFs, whatever the case of the extension", arguments: ["test.pdf", "Invoice.PDF", "a b c.Pdf"])
    func matchesPDFs(name: String) {
        let rule = TestRule.make(destination: destination)
        #expect(Evaluator.matchingRules(for: facts(name), in: [rule]) == [rule])
    }

    @Test("It leaves other files alone", arguments: ["photo.jpg", "notes.txt", "pdf", "report.pdf.zip"])
    func ignoresOthers(name: String) {
        #expect(Evaluator.matchingRules(for: facts(name), in: [TestRule.make(destination: destination)]).isEmpty)
    }

    @Test("It moves to the chosen destination, which can be read back from saved rules")
    func destinationRoundTrip() throws {
        let rule = TestRule.make(destination: destination)
        #expect(rule.actions == [.move(to: destination)])
        let saved = try JSONDecoder().decode([Rule].self, from: JSONEncoder().encode([rule]))
        #expect(TestRule.destination(in: saved) == destination)
    }

    @Test("Without the test rule there is no destination")
    func noDestination() {
        #expect(TestRule.destination(in: []) == nil)
    }
}
