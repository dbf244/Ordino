import Foundation
import OrdinoCore
import Testing

/// The JSON format is what users will export and share, so it must be stable.
@Suite("Model coding")
struct ModelCodingTests {
    let ruleID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
    let folderID = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
    let watchedID = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()

    var sampleRule: Rule {
        Rule(
            id: ruleID,
            name: "Invoices",
            isEnabled: true,
            conditions: ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
                .name(NameCondition(operator: .contains, value: "invoice", caseSensitive: false)),
            ]),
            actions: [.move(to: FolderReference(folderID: folderID, displayPath: "/Users/someone/Invoices"))],
            continuesToNextRule: false
        )
    }

    func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    @Test("A rule encodes to the documented JSON")
    func ruleJSON() throws {
        let json = try encode(sampleRule)
        let expected = #"{"actions":[{"destination":{"displayPath":"\/Users\/someone\/Invoices","folderID":"22222222-2222-2222-2222-222222222222"},"type":"move"}],"conditions":{"conditions":[{"operator":"is","type":"extension","values":["pdf"]},{"caseSensitive":false,"operator":"contains","type":"name","value":"invoice"}],"match":"all"},"continuesToNextRule":false,"id":"11111111-1111-1111-1111-111111111111","isEnabled":true,"name":"Invoices"}"#
        #expect(json == expected)
    }

    @Test("A rule decodes back to the same value")
    func ruleRoundTrip() throws {
        let data = try JSONEncoder().encode(sampleRule)
        #expect(try JSONDecoder().decode(Rule.self, from: data) == sampleRule)
    }

    @Test("A watched folder round-trips with its rules")
    func watchedFolderRoundTrip() throws {
        let watched = WatchedFolder(id: watchedID, folderID: folderID, rules: [sampleRule])
        let data = try JSONEncoder().encode(watched)
        #expect(try JSONDecoder().decode(WatchedFolder.self, from: data) == watched)
    }

    @Test("Every operator round-trips", arguments: TextOperator.allCases)
    func textOperators(op: TextOperator) throws {
        let condition = Condition.name(NameCondition(operator: op, value: "x", caseSensitive: true))
        #expect(try JSONDecoder().decode(Condition.self, from: JSONEncoder().encode(condition)) == condition)
    }

    @Test("Unknown condition types are rejected, not silently ignored")
    func unknownCondition() {
        let json = Data(#"{"type":"colour","value":"red"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Condition.self, from: json)
        }
    }

    @Test("Unknown action types are rejected, not silently ignored")
    func unknownAction() {
        let json = Data(#"{"type":"shred"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RuleAction.self, from: json)
        }
    }
}
