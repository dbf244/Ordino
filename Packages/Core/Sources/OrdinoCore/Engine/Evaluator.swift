import Foundation

/// Decides which rules apply to a file. Pure: no disk access, no side effects.
/// The Simulator (Achievement 5) uses this same code, so a simulation and the
/// real run can never disagree.
///
/// Safety defaults: an empty group, an empty value or an invalid pattern never
/// matches, so a half-finished rule cannot act on every file.
public enum Evaluator {
    /// The rules that run for `file`, in order: the first enabled match, plus
    /// the following matches for as long as each rule says to keep checking.
    public static func matchingRules(for file: FileFacts, in rules: [Rule]) -> [Rule] {
        var matched: [Rule] = []
        for rule in rules where rule.isEnabled && matches(rule.conditions, file) {
            matched.append(rule)
            if !rule.continuesToNextRule {
                break
            }
        }
        return matched
    }

    public static func matches(_ group: ConditionGroup, _ file: FileFacts) -> Bool {
        guard !group.conditions.isEmpty else { return false }
        switch group.match {
        case .all:
            return group.conditions.allSatisfy { matches($0, file) }
        case .any:
            return group.conditions.contains { matches($0, file) }
        }
    }

    public static func matches(_ condition: Condition, _ file: FileFacts) -> Bool {
        switch condition {
        case .name(let name):
            matches(name, file.name)
        case .fileExtension(let ext):
            matches(ext, file.fileExtension)
        }
    }

    // MARK: - Name

    private static func matches(_ condition: NameCondition, _ name: String) -> Bool {
        let value = condition.value
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // Foundation's comparisons treat decomposed and composed accents as equal.
        let options: String.CompareOptions = condition.caseSensitive ? [] : [.caseInsensitive]
        switch condition.operator {
        case .is:
            return name.compare(value, options: options) == .orderedSame
        case .isNot:
            return name.compare(value, options: options) != .orderedSame
        case .contains:
            return name.range(of: value, options: options) != nil
        case .doesNotContain:
            return name.range(of: value, options: options) == nil
        case .startsWith:
            return name.range(of: value, options: options.union(.anchored)) != nil
        case .endsWith:
            return name.range(of: value, options: options.union([.anchored, .backwards])) != nil
        case .matchesPattern:
            return matchesPattern(value, in: name, caseSensitive: condition.caseSensitive)
        }
    }

    private static func matchesPattern(_ pattern: String, in name: String, caseSensitive: Bool) -> Bool {
        // Regular expressions compare code points, so normalize both sides first.
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        guard let regex = try? NSRegularExpression(pattern: pattern.precomposedStringWithCanonicalMapping, options: options) else {
            return false
        }
        let text = name.precomposedStringWithCanonicalMapping
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: - Extension

    private static func matches(_ condition: ExtensionCondition, _ fileExtension: String) -> Bool {
        let values = Set(condition.values.compactMap(normalizedExtension))
        guard !values.isEmpty else { return false }
        switch condition.operator {
        case .is, .isOneOf:
            return values.contains(fileExtension)
        case .isNot:
            return !values.contains(fileExtension)
        }
    }

    /// "PDF", ".pdf" and " pdf " all mean "pdf". Empty values are dropped.
    private static func normalizedExtension(_ value: String) -> String? {
        var trimmed = Substring(value.trimmingCharacters(in: .whitespacesAndNewlines))
        while trimmed.hasPrefix(".") {
            trimmed = trimmed.dropFirst()
        }
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }
}
