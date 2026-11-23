import Foundation
import OrdinoCore
import Testing

/// Every name and extension case the Evaluator supports.
@Suite("Evaluator")
struct EvaluatorTests {
    func file(_ fileName: String, directory: Bool = false) -> FileFacts {
        FileFacts(url: URL(fileURLWithPath: "/Watched/\(fileName)"), isDirectory: directory)
    }

    func name(_ op: TextOperator, _ value: String, caseSensitive: Bool = false) -> Condition {
        .name(NameCondition(operator: op, value: value, caseSensitive: caseSensitive))
    }

    // MARK: - File facts

    @Test("Name excludes the extension; extension is lowercased without the dot", arguments: [
        ("Invoice_0042.pdf", "Invoice_0042", "pdf"),
        ("photo.HEIC", "photo", "heic"),
        ("archive.tar.gz", "archive.tar", "gz"),
        ("README", "README", ""),
        ("notes.", "notes.", ""),
        ("v1.2 release notes.txt", "v1.2 release notes", "txt"),
    ])
    func fileFacts(fileName: String, expectedName: String, expectedExtension: String) {
        let facts = file(fileName)
        #expect(facts.name == expectedName)
        #expect(facts.fileExtension == expectedExtension)
    }

    // MARK: - Name

    @Test("Name operators", arguments: [
        // (operator, value, file name, expected)
        (TextOperator.is, "invoice", "invoice.pdf", true),
        (.is, "invoice", "invoice 2.pdf", false),
        (.is, "invoice", "Invoice.pdf", true),
        (.isNot, "invoice", "receipt.pdf", true),
        (.isNot, "invoice", "INVOICE.pdf", false),
        (.contains, "invoice", "march-invoice-2026.pdf", true),
        (.contains, "invoice", "Invoice_0042_Acme.pdf", true),
        (.contains, "invoice", "receipt.pdf", false),
        (.contains, "pdf", "notes.pdf", false),
        (.doesNotContain, "draft", "final.docx", true),
        (.doesNotContain, "draft", "Draft v2.docx", false),
        (.startsWith, "Screenshot", "Screenshot 2026-11-23 at 10.00.png", true),
        (.startsWith, "screenshot", "Screenshot 2026.png", true),
        (.startsWith, "shot", "Screenshot.png", false),
        (.endsWith, "0042", "Invoice_0042.pdf", true),
        (.endsWith, "pdf", "Invoice.pdf", false),
        (.endsWith, "Invoice", "Invoice_0042.pdf", false),
    ])
    func nameOperators(op: TextOperator, value: String, fileName: String, expected: Bool) {
        #expect(Evaluator.matches(name(op, value), file(fileName)) == expected)
    }

    @Test("Case-sensitive name conditions respect case")
    func caseSensitive() {
        #expect(Evaluator.matches(name(.contains, "Invoice", caseSensitive: true), file("Invoice.pdf")))
        #expect(!Evaluator.matches(name(.contains, "Invoice", caseSensitive: true), file("invoice.pdf")))
        #expect(!Evaluator.matches(name(.is, "invoice", caseSensitive: true), file("Invoice.pdf")))
        #expect(Evaluator.matches(name(.isNot, "invoice", caseSensitive: true), file("Invoice.pdf")))
    }

    @Test("Accented names match whatever the Unicode normalization (macOS uses decomposed names)")
    func unicodeNormalization() {
        let decomposed = "Cafe\u{301}.pdf"  // "Café" as e + combining accent
        let composed = "Caf\u{E9}"          // "Café" as a single é
        #expect(Evaluator.matches(name(.is, composed), file(decomposed)))
        #expect(Evaluator.matches(name(.contains, "afé"), file(decomposed)))
        #expect(Evaluator.matches(name(.endsWith, "É"), file(decomposed)))
        #expect(Evaluator.matches(name(.matchesPattern, "^caf\u{E9}$"), file(decomposed)))
        #expect(!Evaluator.matches(name(.is, "Cafe"), file(decomposed)), "Accents are not ignored")
    }

    @Test("Pattern conditions use regular expressions")
    func patterns() {
        #expect(Evaluator.matches(name(.matchesPattern, #"^invoice[-_ ]\d{4}$"#), file("Invoice-2026.pdf")))
        #expect(!Evaluator.matches(name(.matchesPattern, #"^invoice[-_ ]\d{4}$"#), file("Invoice-26.pdf")))
        #expect(Evaluator.matches(name(.matchesPattern, #"\d+"#), file("scan 12.jpg")), "Matches anywhere in the name")
        #expect(!Evaluator.matches(name(.matchesPattern, "INVOICE", caseSensitive: true), file("invoice.pdf")))
    }

    @Test("An invalid pattern never matches")
    func invalidPattern() {
        #expect(!Evaluator.matches(name(.matchesPattern, "([unclosed"), file("([unclosed.pdf")))
    }

    @Test("An empty value never matches, so a half-filled rule can't touch every file", arguments: TextOperator.allCases)
    func emptyValue(op: TextOperator) {
        #expect(!Evaluator.matches(name(op, ""), file("anything.pdf")))
        #expect(!Evaluator.matches(name(op, "   "), file("anything.pdf")))
    }

    @Test("Folders are matched by name too")
    func folders() {
        #expect(Evaluator.matches(name(.startsWith, "Project"), file("Project Alpha", directory: true)))
    }

    // MARK: - Extension

    @Test("Extension operators", arguments: [
        // (operator, values, file name, expected)
        (ExtensionOperator.is, ["pdf"], "invoice.pdf", true),
        (.is, ["pdf"], "invoice.PDF", true),
        (.is, ["PDF"], "invoice.pdf", true),
        (.is, [".pdf"], "invoice.pdf", true),
        (.is, [" pdf "], "invoice.pdf", true),
        (.is, ["pdf"], "invoice.pdf.zip", false),
        (.is, ["pdf"], "pdf", false),
        (.is, ["gz"], "archive.tar.gz", true),
        (.is, ["tar.gz"], "archive.tar.gz", false),
        (.isNot, ["pdf"], "photo.jpg", true),
        (.isNot, ["pdf"], "invoice.pdf", false),
        (.isNot, ["pdf"], "README", true),
        (.isOneOf, ["jpg", "png", "heic"], "photo.HEIC", true),
        (.isOneOf, ["jpg", "png", "heic"], "photo.png", true),
        (.isOneOf, ["jpg", "png", "heic"], "photo.gif", false),
        (.isOneOf, ["jpg", ".PNG"], "photo.png", true),
        (.isOneOf, [], "photo.png", false),
    ])
    func extensionOperators(op: ExtensionOperator, values: [String], fileName: String, expected: Bool) {
        let condition = Condition.fileExtension(ExtensionCondition(operator: op, values: values))
        #expect(Evaluator.matches(condition, file(fileName)) == expected)
    }

    @Test("Files without an extension")
    func noExtension() {
        let isPDF = Condition.fileExtension(ExtensionCondition(operator: .is, values: ["pdf"]))
        #expect(!Evaluator.matches(isPDF, file("Makefile")))
        let empty = Condition.fileExtension(ExtensionCondition(operator: .is, values: [""]))
        #expect(!Evaluator.matches(empty, file("Makefile")), "An empty extension value never matches")
    }

    // MARK: - Groups

    @Test("ALL needs every condition, ANY needs one")
    func groups() {
        let conditions = [
            Condition.fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
            name(.contains, "invoice"),
        ]
        let all = ConditionGroup(match: .all, conditions: conditions)
        let any = ConditionGroup(match: .any, conditions: conditions)

        #expect(Evaluator.matches(all, file("invoice.pdf")))
        #expect(!Evaluator.matches(all, file("receipt.pdf")))
        #expect(Evaluator.matches(any, file("receipt.pdf")))
        #expect(Evaluator.matches(any, file("invoice.docx")))
        #expect(!Evaluator.matches(any, file("receipt.docx")))
    }

    @Test("An empty group never matches", arguments: [ConditionGroup.Match.all, .any])
    func emptyGroup(match: ConditionGroup.Match) {
        #expect(!Evaluator.matches(ConditionGroup(match: match, conditions: []), file("invoice.pdf")))
    }

    // MARK: - Rules

    func rule(_ title: String, ext: String, enabled: Bool = true, continues: Bool = false) -> Rule {
        Rule(
            name: title,
            isEnabled: enabled,
            conditions: ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: [ext])),
            ]),
            actions: [],
            continuesToNextRule: continues
        )
    }

    @Test("The first matching rule wins")
    func firstMatchWins() {
        let rules = [rule("Images", ext: "png"), rule("PDF A", ext: "pdf"), rule("PDF B", ext: "pdf")]
        #expect(Evaluator.matchingRules(for: file("a.pdf"), in: rules).map(\.name) == ["PDF A"])
    }

    @Test("Disabled rules are skipped")
    func disabledSkipped() {
        let rules = [rule("Off", ext: "pdf", enabled: false), rule("On", ext: "pdf")]
        #expect(Evaluator.matchingRules(for: file("a.pdf"), in: rules).map(\.name) == ["On"])
    }

    @Test("A rule can let the following rules run too")
    func keepChecking() {
        let rules = [rule("First", ext: "pdf", continues: true), rule("Second", ext: "pdf"), rule("Third", ext: "pdf")]
        #expect(Evaluator.matchingRules(for: file("a.pdf"), in: rules).map(\.name) == ["First", "Second"])
    }

    @Test("No rule matches")
    func noMatch() {
        #expect(Evaluator.matchingRules(for: file("a.txt"), in: [rule("PDF", ext: "pdf")]).isEmpty)
    }
}
