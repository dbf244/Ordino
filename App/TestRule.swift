import Foundation
import OrdinoCore

/// The one rule of Achievement 2, defined in code: every PDF that lands in
/// the watched folder moves to a destination the user picked. The rule
/// editor (Achievement 6) replaces it.
enum TestRule {
    static let id = UUID(uuidString: "5DF0A2B4-0C1E-4C7A-9E43-0A7D1B2C3E4F") ?? UUID()

    static func make(destination: FolderReference) -> Rule {
        Rule(
            id: id,
            name: String(localized: "PDFs"),
            isEnabled: true,
            conditions: ConditionGroup(match: .all, conditions: [
                .fileExtension(ExtensionCondition(operator: .is, values: ["pdf"])),
            ]),
            actions: [.move(to: destination)],
            continuesToNextRule: false
        )
    }

    /// The destination of the test rule among saved rules, if there is one.
    static func destination(in rules: [Rule]) -> FolderReference? {
        guard let rule = rules.first(where: { $0.id == id }) else { return nil }
        for case .move(let destination) in rule.actions {
            return destination
        }
        return nil
    }
}
