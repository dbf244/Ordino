import Foundation
import os

/// Decides which rules apply to a file. Pure: no disk access, no side effects,
/// and "now" is a parameter. The Simulator (Achievement 5) uses this same code,
/// so a simulation and the real run can never disagree.
///
/// Safety defaults, so a half-finished rule cannot act on every file:
/// an empty group, an empty value, an invalid pattern, a non-positive amount
/// or an unknown fact never matches, not even in a negative condition.
public enum Evaluator {
    /// The rules that run for `file`, in order: the first enabled match, plus
    /// the following matches for as long as each rule says to keep checking.
    public static func matchingRules(for file: FileFacts, in rules: [Rule], now: Date = .now) -> [Rule] {
        var matched: [Rule] = []
        for rule in rules where rule.isEnabled && matches(rule.conditions, file, now: now) {
            matched.append(rule)
            if !rule.continuesToNextRule {
                break
            }
        }
        return matched
    }

    public static func matches(_ group: ConditionGroup, _ file: FileFacts, now: Date = .now) -> Bool {
        guard !group.conditions.isEmpty else { return false }
        switch group.match {
        case .all:
            return group.conditions.allSatisfy { matches($0, file, now: now) }
        case .any:
            return group.conditions.contains { matches($0, file, now: now) }
        }
    }

    public static func matches(_ condition: Condition, _ file: FileFacts, now: Date = .now) -> Bool {
        switch condition {
        case .name(let name):
            matches(name, file.name)
        case .fileExtension(let ext):
            matches(ext, file.fileExtension)
        case .kind(let kind):
            switch kind.operator {
            case .is: file.kind == kind.kind
            case .isNot: file.kind != kind.kind
            }
        case .size(let size):
            matches(size, file.size)
        case .date(let date):
            matches(date, file, now: now)
        case .tags(let tags):
            matches(tags, file.tags)
        case .downloadSource(let source):
            matches(source, file.whereFroms)
        case .screenshot(let screenshot):
            file.isScreenshot.map { $0 == screenshot.isScreenshot } ?? false
        case .group(let group):
            matches(group, file, now: now)
        }
    }

    /// The facts that must be read from disk to evaluate `rules`. Facts no
    /// rule uses (a folder's total size, for example) are never read.
    public static func requiredFacts(for rules: [Rule]) -> FactSet {
        rules.filter(\.isEnabled).reduce(into: FactSet()) { facts, rule in
            facts.formUnion(requiredFacts(for: rule.conditions))
        }
    }

    private static func requiredFacts(for group: ConditionGroup) -> FactSet {
        group.conditions.reduce(into: FactSet()) { facts, condition in
            switch condition {
            case .name, .fileExtension, .kind: break
            case .size: facts.insert(.size)
            case .date(let date): facts.insert(date.attribute == .lastOpened ? .lastOpened : .dates)
            case .tags: facts.insert(.tags)
            case .downloadSource: facts.insert(.downloadSource)
            case .screenshot: facts.insert(.screenshot)
            case .group(let nested): facts.formUnion(requiredFacts(for: nested))
            }
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
            return PatternCache.shared.matches(value, in: name, caseSensitive: condition.caseSensitive)
        }
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

    // MARK: - Size

    private static func matches(_ condition: SizeCondition, _ size: Int64?) -> Bool {
        guard let size, condition.amount >= 0 else { return false }
        switch condition.operator {
        case .greaterThan: return size > condition.bytes
        case .lessThan: return size < condition.bytes
        }
    }

    // MARK: - Dates

    private static func matches(_ condition: DateCondition, _ file: FileFacts, now: Date) -> Bool {
        let date: Date? = switch condition.attribute {
        case .added: file.dateAdded
        case .created: file.creationDate
        case .modified: file.modificationDate
        case .lastOpened: file.lastOpenedDate
        }
        guard let date, condition.amount > 0 else { return false }
        let component: Calendar.Component = switch condition.unit {
        case .hours: .hour
        case .days: .day
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
        guard let threshold = Calendar.current.date(byAdding: component, value: -condition.amount, to: now) else {
            return false
        }
        switch condition.operator {
        case .moreThan: return date < threshold
        case .lessThan: return date > threshold
        }
    }

    // MARK: - Tags

    private static func matches(_ condition: TagCondition, _ tags: [String]?) -> Bool {
        guard let tags else { return false }
        switch condition.operator {
        case .hasNoTags:
            return tags.isEmpty
        case .hasAnyTag:
            return !tags.isEmpty
        case .hasTag, .doesNotHaveTag:
            let wanted = condition.tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !wanted.isEmpty else { return false }
            let has = tags.contains { $0.compare(wanted, options: .caseInsensitive) == .orderedSame }
            return condition.operator == .hasTag ? has : !has
        }
    }

    // MARK: - Download source

    private static func matches(_ condition: DownloadSourceCondition, _ whereFroms: [String]?) -> Bool {
        guard let whereFroms, let domain = normalizedDomain(condition.domain) else { return false }
        let hosts = whereFroms.compactMap { URL(string: $0)?.host?.lowercased() }
        let isFrom = hosts.contains { $0 == domain || $0.hasSuffix("." + domain) }
        switch condition.operator {
        case .isFrom: return isFrom
        case .isNotFrom: return !isFrom
        }
    }

    /// Accepts "apple.com", "www.apple.com" or a pasted "https://apple.com/".
    private static func normalizedDomain(_ value: String) -> String? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.contains("://"), let host = URL(string: text)?.host {
            text = host.lowercased()
        }
        while text.hasPrefix(".") {
            text.removeFirst()
        }
        while text.hasSuffix("/") || text.hasSuffix(".") {
            text.removeLast()
        }
        return text.isEmpty ? nil : text
    }
}

/// Compiled regular expressions, so evaluating many files doesn't recompile
/// the same pattern for each one. Invalid patterns are remembered too.
final class PatternCache: Sendable {
    static let shared = PatternCache()

    private struct Key: Hashable {
        let pattern: String
        let caseSensitive: Bool
    }

    private let cache = OSAllocatedUnfairLock<[Key: NSRegularExpression?]>(initialState: [:])

    func matches(_ pattern: String, in name: String, caseSensitive: Bool) -> Bool {
        guard let regex = regex(pattern, caseSensitive: caseSensitive) else { return false }
        // Regular expressions compare code points, so normalize the name first.
        let text = name.precomposedStringWithCanonicalMapping
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func regex(_ pattern: String, caseSensitive: Bool) -> NSRegularExpression? {
        let key = Key(pattern: pattern, caseSensitive: caseSensitive)
        return cache.withLock { cache in
            if let cached = cache[key] {
                return cached
            }
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            let compiled = try? NSRegularExpression(pattern: pattern.precomposedStringWithCanonicalMapping, options: options)
            if cache.count > 256 {
                cache.removeAll()
            }
            cache[key] = compiled
            return compiled
        }
    }
}
