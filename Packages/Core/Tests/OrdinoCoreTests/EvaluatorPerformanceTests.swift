import Foundation
import OrdinoCore
import Testing

@Suite("Evaluator performance")
struct EvaluatorPerformanceTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let destination = FolderReference(folderID: UUID(), displayPath: "/Destination")

    /// Rules shaped like the five templates, using every kind of condition.
    var templateRules: [Rule] {
        func rule(_ name: String, _ group: ConditionGroup) -> Rule {
            Rule(name: name, isEnabled: true, conditions: group, actions: [.move(to: destination)], continuesToNextRule: false)
        }
        return [
            rule("Archive invoices", ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
                .group(ConditionGroup(match: .any, conditions: [
                    .name(NameCondition(operator: .contains, value: "invoice")),
                    .name(NameCondition(operator: .matchesPattern, value: #"factura[-_ ]?\d+"#)),
                ])),
            ])),
            rule("Screenshots by month", ConditionGroup(match: .all, conditions: [
                .screenshot(ScreenshotCondition(isScreenshot: true)),
                .kind(KindCondition(operator: .is, kind: .image)),
            ])),
            rule("Clean old installers", ConditionGroup(match: .all, conditions: [
                .kind(KindCondition(operator: .is, kind: .installer)),
                .date(DateCondition(attribute: .added, operator: .moreThan, amount: 2, unit: .weeks)),
                .downloadSource(DownloadSourceCondition(operator: .isNotFrom, domain: "apple.com")),
            ])),
            rule("Big videos", ConditionGroup(match: .all, conditions: [
                .kind(KindCondition(operator: .is, kind: .video)),
                .size(SizeCondition(operator: .greaterThan, amount: 500, unit: .megabytes)),
                .tags(TagCondition(operator: .doesNotHaveTag, tag: "Keep")),
            ])),
            rule("Tidy Desktop", ConditionGroup(match: .any, conditions: [
                .date(DateCondition(attribute: .modified, operator: .moreThan, amount: 3, unit: .days)),
                .date(DateCondition(attribute: .lastOpened, operator: .moreThan, amount: 1, unit: .months)),
            ])),
        ]
    }

    /// 10,000 files with varied names, kinds, sizes, dates, tags and sources.
    func simulatedFiles() -> [FileFacts] {
        let names = ["invoice-%d.pdf", "factura_%d.pdf", "Screenshot %d.png", "Setup %d.dmg", "movie %d.mov",
                     "notes %d.txt", "photo %d.HEIC", "archive %d.zip", "Song %d.mp3", "Folder %d"]
        return (0..<10_000).map { index in
            let pattern = names[index % names.count]
            return FileFacts(
                url: URL(fileURLWithPath: "/Watched/" + pattern.replacingOccurrences(of: "%d", with: String(index))),
                isDirectory: pattern.hasPrefix("Folder"),
                size: Int64(index) * 97_331,
                dateAdded: now.addingTimeInterval(-Double(index % 40) * 86_400),
                creationDate: now.addingTimeInterval(-Double(index % 90) * 86_400),
                modificationDate: now.addingTimeInterval(-Double(index % 10) * 86_400),
                lastOpenedDate: index % 3 == 0 ? nil : now.addingTimeInterval(-Double(index % 60) * 86_400),
                tags: index % 5 == 0 ? ["Keep"] : [],
                whereFroms: index % 2 == 0 ? ["https://dl.example.com/file"] : [],
                isScreenshot: pattern.hasPrefix("Screenshot")
            )
        }
    }

    @Test("Evaluating 10,000 simulated files takes under 1 second")
    func tenThousandFiles() {
        let files = simulatedFiles()
        let rules = templateRules
        let clock = ContinuousClock()
        var matched = 0

        let elapsed = clock.measure {
            for file in files where !Evaluator.matchingRules(for: file, in: rules, now: now).isEmpty {
                matched += 1
            }
        }

        #expect(elapsed < .seconds(1), "Took \(elapsed)")
        #expect(matched > 0 && matched < files.count, "Some files match, not all (\(matched))")
    }
}
