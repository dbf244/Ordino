import Foundation
import OrdinoCore
import Testing

/// Every condition checked against real files on disk, with real metadata.
@Suite("Conditions on real files")
struct ConditionFileTests {
    let folder: TemporaryFolder
    let now = Date()

    init() throws {
        folder = try TemporaryFolder()
    }

    func facts(_ url: URL) throws -> FileFacts {
        try #require(FileFacts.read(url))
    }

    func check(_ condition: Condition, _ url: URL, at date: Date? = nil) throws -> Bool {
        Evaluator.matches(condition, try facts(url), now: date ?? now)
    }

    // MARK: - Kind

    @Test("Kind is recognized from real files", arguments: [
        ("photo.jpg", FileKind.image),
        ("drawing.HEIC", .image),
        ("icon.svg", .image),
        ("clip.mov", .video),
        ("film.mp4", .video),
        ("song.mp3", .audio),
        ("voice.m4a", .audio),
        ("report.pdf", .document),
        ("letter.docx", .document),
        ("budget.xlsx", .document),
        ("slides.key", .document),
        ("notes.txt", .document),
        ("backup.zip", .archive),
        ("source.tar.gz", .archive),
        ("bundle.7z", .archive),
        ("Installer.dmg", .installer),
        ("Setup.pkg", .installer),
        ("Makefile", .other),
        ("data.xyz123", .other),
    ])
    func kindOfFiles(name: String, expected: FileKind) throws {
        let file = try folder.write(name)
        #expect(try facts(file).kind == expected)
        #expect(try check(.kind(KindCondition(operator: .is, kind: expected)), file))
        #expect(try !check(.kind(KindCondition(operator: .isNot, kind: expected)), file))
    }

    @Test("A folder is a folder, an app bundle is an application")
    func kindOfFolders() throws {
        let plain = try folder.makeFolder("Projects")
        let app = try folder.makeFolder("Tool.app")
        #expect(try facts(plain).kind == .folder)
        #expect(try facts(app).kind == .application)
        #expect(try !check(.kind(KindCondition(operator: .is, kind: .folder)), app))
    }

    // MARK: - Size

    @Test("Size compares real file sizes in decimal units, like Finder")
    func size() throws {
        let file = try folder.write("two-kb.bin", bytes: 2_000)
        #expect(try facts(file).size == 2_000)
        #expect(try check(.size(SizeCondition(operator: .greaterThan, amount: 1, unit: .kilobytes)), file))
        #expect(try !check(.size(SizeCondition(operator: .greaterThan, amount: 2, unit: .kilobytes)), file), "Exactly 2 KB is not larger than 2 KB")
        #expect(try check(.size(SizeCondition(operator: .lessThan, amount: 2.5, unit: .kilobytes)), file))
        #expect(try !check(.size(SizeCondition(operator: .lessThan, amount: 1, unit: .megabytes)), try folder.write("big.bin", bytes: 1_500_000)))
    }

    @Test("A folder's size is the total of everything inside it")
    func folderSize() throws {
        let album = try folder.makeFolder("Album")
        try Data(count: 600_000).write(to: album.appendingPathComponent("a.jpg"))
        let inner = album.appendingPathComponent("More", isDirectory: true)
        try FileManager.default.createDirectory(at: inner, withIntermediateDirectories: true)
        try Data(count: 500_000).write(to: inner.appendingPathComponent("b.jpg"))

        #expect(try facts(album).size == 1_100_000)
        #expect(try check(.size(SizeCondition(operator: .greaterThan, amount: 1, unit: .megabytes)), album))
    }

    // MARK: - Dates

    @Test("Created and modified dates are read from the file")
    func createdAndModified() throws {
        let file = try folder.write("old.txt")
        let tenDaysAgo = now.addingTimeInterval(-10 * 86_400)
        let twoDaysAgo = now.addingTimeInterval(-2 * 86_400)
        try FileMetadata.setDates(created: tenDaysAgo, modified: twoDaysAgo, on: file)

        func date(_ attribute: DateAttribute, _ op: DateOperator, _ amount: Int) -> Condition {
            .date(DateCondition(attribute: attribute, operator: op, amount: amount, unit: .days))
        }
        #expect(try check(date(.created, .moreThan, 7), file))
        #expect(try !check(date(.created, .lessThan, 7), file))
        #expect(try check(date(.modified, .lessThan, 7), file))
        #expect(try !check(date(.modified, .moreThan, 7), file))
    }

    @Test("Date added is read from the file system")
    func dateAdded() throws {
        let file = try folder.write("new.txt")
        let added = try #require(try facts(file).dateAdded)
        #expect(abs(added.timeIntervalSince(now)) < 60)

        let condition = Condition.date(DateCondition(attribute: .added, operator: .moreThan, amount: 3, unit: .days))
        #expect(try !check(condition, file))
        #expect(try check(condition, file, at: now.addingTimeInterval(4 * 86_400)), "Three days later it is old enough")
    }

    @Test("Last opened is read from the metadata macOS records")
    func lastOpened() throws {
        let file = try folder.write("opened.pdf")
        let condition = Condition.date(DateCondition(attribute: .lastOpened, operator: .moreThan, amount: 1, unit: .months))
        #expect(try facts(file).lastOpenedDate == nil)
        #expect(try !check(condition, file), "Never opened: unknown, so no match")

        try FileMetadata.setLastOpened(now.addingTimeInterval(-40 * 86_400), on: file)
        #expect(try facts(file).lastOpenedDate != nil)
        #expect(try check(condition, file))
    }

    // MARK: - Tags

    @Test("Finder tags are read from the file")
    func tags() throws {
        let tagged = try folder.write("tagged.pdf")
        let plain = try folder.write("plain.pdf")
        try FileMetadata.setTags(["Red", "Work"], on: tagged)

        func tag(_ op: TagOperator, _ name: String = "") -> Condition {
            .tags(TagCondition(operator: op, tag: name))
        }
        #expect(try Set(facts(tagged).tags ?? []) == ["Red", "Work"])
        #expect(try check(tag(.hasTag, "red"), tagged), "Tag names ignore case")
        #expect(try !check(tag(.hasTag, "Blue"), tagged))
        #expect(try check(tag(.doesNotHaveTag, "Blue"), tagged))
        #expect(try !check(tag(.doesNotHaveTag, "Work"), tagged))
        #expect(try check(tag(.hasAnyTag), tagged))
        #expect(try !check(tag(.hasNoTags), tagged))
        #expect(try check(tag(.hasNoTags), plain))
        #expect(try !check(tag(.hasAnyTag), plain))
    }

    // MARK: - Download source

    @Test("The download source is read from the metadata browsers record (kMDItemWhereFroms)")
    func downloadSource() throws {
        let download = try folder.write("installer.dmg")
        try FileMetadata.setWhereFroms(["https://dl.google.com/chrome/installer.dmg", "https://www.google.com/chrome/"], on: download)
        let local = try folder.write("local.dmg")

        func source(_ op: SourceOperator, _ domain: String) -> Condition {
            .downloadSource(DownloadSourceCondition(operator: op, domain: domain))
        }
        #expect(try check(source(.isFrom, "google.com"), download), "Subdomains count")
        #expect(try check(source(.isFrom, "dl.google.com"), download))
        #expect(try check(source(.isFrom, "https://Google.com/"), download), "A pasted URL works too")
        #expect(try !check(source(.isFrom, "apple.com"), download))
        #expect(try !check(source(.isFrom, "gle.com"), download), "Only whole domain parts match")
        #expect(try check(source(.isNotFrom, "apple.com"), download))
        #expect(try !check(source(.isFrom, "google.com"), local))
        #expect(try check(source(.isNotFrom, "google.com"), local), "A local file was not downloaded from anywhere")
    }

    // MARK: - Screenshot

    @Test("Screenshots are recognized from the metadata screencapture records (kMDItemIsScreenCapture)")
    func screenshot() throws {
        let shot = try folder.write("Screenshot 2026-11-23 at 10.00.00.png")
        try FileMetadata.markAsScreenshot(shot)
        let photo = try folder.write("Screenshot of nothing.png")

        #expect(try facts(shot).isScreenshot == true)
        #expect(try check(.screenshot(ScreenshotCondition(isScreenshot: true)), shot))
        #expect(try !check(.screenshot(ScreenshotCondition(isScreenshot: true)), photo), "The name alone doesn't make a screenshot")
        #expect(try check(.screenshot(ScreenshotCondition(isScreenshot: false)), photo))
    }

    // MARK: - Reading only what is needed

    @Test("Facts nobody needs are not read")
    func lazyFacts() throws {
        let file = try folder.write("lazy.pdf", bytes: 500)
        try FileMetadata.setTags(["Red"], on: file)
        let minimal = try #require(FileFacts.read(file, needing: []))
        #expect(minimal.name == "lazy")
        #expect(minimal.kind == .document)
        #expect(minimal.size == nil)
        #expect(minimal.tags == nil)

        let sized = try #require(FileFacts.read(file, needing: [.size]))
        #expect(sized.size == 500)
        #expect(sized.tags == nil)
    }

    @Test("The facts a set of rules needs are worked out from its conditions")
    func requiredFacts() {
        let rule = Rule(
            name: "Mixed",
            isEnabled: true,
            conditions: ConditionGroup(match: .any, conditions: [
                .name(NameCondition(operator: .contains, value: "x")),
                .group(ConditionGroup(match: .all, conditions: [
                    .size(SizeCondition(operator: .greaterThan, amount: 1, unit: .megabytes)),
                    .tags(TagCondition(operator: .hasAnyTag, tag: "")),
                ])),
            ]),
            actions: [],
            continuesToNextRule: false
        )
        #expect(Evaluator.requiredFacts(for: [rule]) == [.size, .tags])
        #expect(Evaluator.requiredFacts(for: []) == [])
    }
}
