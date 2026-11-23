import Foundation
import OrdinoCore
import Testing

/// The new conditions and nested groups, on simulated files (no disk).
@Suite("Condition logic")
struct ConditionLogicTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func file(
        _ name: String = "file.pdf",
        directory: Bool = false,
        size: Int64? = nil,
        added: Date? = nil,
        created: Date? = nil,
        modified: Date? = nil,
        lastOpened: Date? = nil,
        tags: [String]? = nil,
        whereFroms: [String]? = nil,
        isScreenshot: Bool? = nil
    ) -> FileFacts {
        FileFacts(
            url: URL(fileURLWithPath: "/Watched/\(name)"),
            isDirectory: directory,
            size: size,
            dateAdded: added,
            creationDate: created,
            modificationDate: modified,
            lastOpenedDate: lastOpened,
            tags: tags,
            whereFroms: whereFroms,
            isScreenshot: isScreenshot
        )
    }

    func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    func check(_ condition: Condition, _ facts: FileFacts) -> Bool {
        Evaluator.matches(condition, facts, now: now)
    }

    // MARK: - Unknown facts never match

    @Test("A fact that is not known never matches, not even a negative condition", arguments: [
        Condition.size(SizeCondition(operator: .greaterThan, amount: 0, unit: .bytes)),
        .size(SizeCondition(operator: .lessThan, amount: 1, unit: .gigabytes)),
        .date(DateCondition(attribute: .added, operator: .moreThan, amount: 1, unit: .days)),
        .date(DateCondition(attribute: .created, operator: .lessThan, amount: 1, unit: .days)),
        .date(DateCondition(attribute: .modified, operator: .moreThan, amount: 1, unit: .days)),
        .date(DateCondition(attribute: .lastOpened, operator: .lessThan, amount: 1, unit: .days)),
        .tags(TagCondition(operator: .hasTag, tag: "Red")),
        .tags(TagCondition(operator: .doesNotHaveTag, tag: "Red")),
        .tags(TagCondition(operator: .hasNoTags, tag: "")),
        .tags(TagCondition(operator: .hasAnyTag, tag: "")),
        .downloadSource(DownloadSourceCondition(operator: .isFrom, domain: "apple.com")),
        .downloadSource(DownloadSourceCondition(operator: .isNotFrom, domain: "apple.com")),
        .screenshot(ScreenshotCondition(isScreenshot: true)),
        .screenshot(ScreenshotCondition(isScreenshot: false)),
    ])
    func unknownNeverMatches(condition: Condition) {
        #expect(!check(condition, file()))
    }

    // MARK: - Size

    @Test("Size units are decimal, like Finder", arguments: [
        (SizeUnit.bytes, 1.0, Int64(1)),
        (.kilobytes, 1, 1_000),
        (.megabytes, 500, 500_000_000),
        (.gigabytes, 1.5, 1_500_000_000),
    ])
    func sizeUnits(unit: SizeUnit, amount: Double, bytes: Int64) {
        #expect(SizeCondition(operator: .greaterThan, amount: amount, unit: unit).bytes == bytes)
    }

    @Test("Size boundaries")
    func sizeBoundaries() {
        let mb = SizeCondition(operator: .greaterThan, amount: 1, unit: .megabytes)
        #expect(!check(.size(mb), file(size: 1_000_000)))
        #expect(check(.size(mb), file(size: 1_000_001)))
        let under = SizeCondition(operator: .lessThan, amount: 1, unit: .kilobytes)
        #expect(check(.size(under), file(size: 0)))
        #expect(!check(.size(under), file(size: 1_000)))
    }

    @Test("A negative size never matches")
    func negativeSize() {
        #expect(!check(.size(SizeCondition(operator: .lessThan, amount: -1, unit: .megabytes)), file(size: 0)))
    }

    // MARK: - Dates

    @Test("More than / less than N units ago", arguments: [
        // (operator, amount, unit, file age in days, expected)
        (DateOperator.moreThan, 3, TimeUnit.days, 4.0, true),
        (.moreThan, 3, .days, 2.0, false),
        (.lessThan, 3, .days, 2.0, true),
        (.lessThan, 3, .days, 4.0, false),
        (.moreThan, 12, .hours, 1.0, true),
        (.lessThan, 12, .hours, 0.25, true),
        (.moreThan, 2, .weeks, 15.0, true),
        (.lessThan, 2, .weeks, 15.0, false),
        (.moreThan, 1, .months, 40.0, true),
        (.lessThan, 1, .months, 20.0, true),
        (.moreThan, 1, .years, 400.0, true),
        (.lessThan, 1, .years, 400.0, false),
    ])
    func relativeDates(op: DateOperator, amount: Int, unit: TimeUnit, age: Double, expected: Bool) {
        let condition = Condition.date(DateCondition(attribute: .modified, operator: op, amount: amount, unit: unit))
        #expect(check(condition, file(modified: daysAgo(age))) == expected)
    }

    @Test("Each date condition reads its own date", arguments: DateAttribute.allCases)
    func dateAttributes(attribute: DateAttribute) {
        let old = daysAgo(30)
        let recent = daysAgo(1)
        let facts = file(
            added: attribute == .added ? old : recent,
            created: attribute == .created ? old : recent,
            modified: attribute == .modified ? old : recent,
            lastOpened: attribute == .lastOpened ? old : recent
        )
        let condition = Condition.date(DateCondition(attribute: attribute, operator: .moreThan, amount: 7, unit: .days))
        #expect(check(condition, facts))
    }

    @Test("A date in the future counts as less than N ago, never as more")
    func futureDate() {
        let future = now.addingTimeInterval(86_400)
        #expect(check(.date(DateCondition(attribute: .modified, operator: .lessThan, amount: 1, unit: .days)), file(modified: future)))
        #expect(!check(.date(DateCondition(attribute: .modified, operator: .moreThan, amount: 1, unit: .days)), file(modified: future)))
    }

    @Test("A zero or negative amount never matches", arguments: [0, -3])
    func invalidAmount(amount: Int) {
        let facts = file(modified: daysAgo(10))
        #expect(!check(.date(DateCondition(attribute: .modified, operator: .moreThan, amount: amount, unit: .days)), facts))
        #expect(!check(.date(DateCondition(attribute: .modified, operator: .lessThan, amount: amount, unit: .days)), facts))
    }

    // MARK: - Tags, source, screenshot, kind

    @Test("An empty tag name never matches")
    func emptyTag() {
        #expect(!check(.tags(TagCondition(operator: .hasTag, tag: " ")), file(tags: ["Red"])))
        #expect(!check(.tags(TagCondition(operator: .doesNotHaveTag, tag: "")), file(tags: ["Red"])))
    }

    @Test("Download source matching", arguments: [
        // (whereFroms, domain, isFrom expected)
        (["https://www.apple.com/macos/"], "apple.com", true),
        (["https://support.apple.com/kb"], "APPLE.COM", true),
        (["https://notapple.com/x"], "apple.com", false),
        (["https://apple.com.evil.example/x"], "apple.com", false),
        (["not a url", "https://github.com/dbf244"], "github.com", true),
        ([], "apple.com", false),
    ])
    func sourceMatching(whereFroms: [String], domain: String, expected: Bool) {
        #expect(check(.downloadSource(DownloadSourceCondition(operator: .isFrom, domain: domain)), file(whereFroms: whereFroms)) == expected)
    }

    @Test("An empty domain never matches")
    func emptyDomain() {
        #expect(!check(.downloadSource(DownloadSourceCondition(operator: .isNotFrom, domain: "  ")), file(whereFroms: [])))
    }

    @Test("Kinds from simulated names", arguments: [
        ("a.png", false, FileKind.image),
        ("a.webm", false, .video),
        ("a.flac", false, .audio),
        ("a.csv", false, .document),
        ("a.rar", false, .archive),
        ("a.mpkg", false, .installer),
        ("Folder", true, .folder),
        ("Thing.app", true, .application),
        ("Holiday.png", true, .folder),
        ("Notes.rtfd", true, .document),
        ("v1.2", true, .folder),
        ("noext", false, .other),
    ])
    func kinds(name: String, directory: Bool, expected: FileKind) {
        #expect(file(name, directory: directory).kind == expected)
    }

    // MARK: - Nested groups

    let isPDF = Condition.fileExtension(ExtensionCondition(operator: .is, values: ["pdf"]))
    let namedInvoice = Condition.name(NameCondition(operator: .contains, value: "invoice"))
    let namedFactura = Condition.name(NameCondition(operator: .contains, value: "factura"))
    let isImage = Condition.kind(KindCondition(operator: .is, kind: .image))
    let tagged = Condition.tags(TagCondition(operator: .hasAnyTag, tag: ""))

    @Test("OR inside AND: a PDF named invoice or factura", arguments: [
        ("invoice-03.pdf", true),
        ("Factura 12.pdf", true),
        ("receipt.pdf", false),
        ("invoice.docx", false),
    ])
    func orInsideAnd(name: String, expected: Bool) {
        let group = ConditionGroup(match: .all, conditions: [
            isPDF,
            .group(ConditionGroup(match: .any, conditions: [namedInvoice, namedFactura])),
        ])
        #expect(Evaluator.matches(group, file(name, tags: []), now: now) == expected)
    }

    @Test("AND inside OR: any image, or a tagged PDF", arguments: [
        ("photo.jpg", [String](), true),
        ("doc.pdf", ["Red"], true),
        ("doc.pdf", [], false),
        ("notes.txt", ["Red"], false),
    ])
    func andInsideOr(name: String, tags: [String], expected: Bool) {
        let group = ConditionGroup(match: .any, conditions: [
            isImage,
            .group(ConditionGroup(match: .all, conditions: [isPDF, tagged])),
        ])
        #expect(Evaluator.matches(group, file(name, tags: tags), now: now) == expected)
    }

    @Test("Groups nest several levels deep")
    func deepNesting() {
        // ALL( pdf, ANY( invoice, ALL( factura, tagged ) ) )
        let group = ConditionGroup(match: .all, conditions: [
            isPDF,
            .group(ConditionGroup(match: .any, conditions: [
                namedInvoice,
                .group(ConditionGroup(match: .all, conditions: [namedFactura, tagged])),
            ])),
        ])
        #expect(Evaluator.matches(group, file("invoice.pdf", tags: []), now: now))
        #expect(Evaluator.matches(group, file("factura.pdf", tags: ["Red"]), now: now))
        #expect(!Evaluator.matches(group, file("factura.pdf", tags: []), now: now))
        #expect(!Evaluator.matches(group, file("factura.txt", tags: ["Red"]), now: now))
    }

    @Test("An empty nested group never matches, in ALL or ANY")
    func emptyNestedGroup() {
        let empty = Condition.group(ConditionGroup(match: .any, conditions: []))
        #expect(!Evaluator.matches(ConditionGroup(match: .all, conditions: [isPDF, empty]), file("a.pdf"), now: now))
        #expect(!Evaluator.matches(ConditionGroup(match: .any, conditions: [empty]), file("a.pdf"), now: now))
        #expect(Evaluator.matches(ConditionGroup(match: .any, conditions: [empty, isPDF]), file("a.pdf"), now: now))
    }
}
