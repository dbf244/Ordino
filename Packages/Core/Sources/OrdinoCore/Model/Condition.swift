import Foundation

/// How a text value is compared with a file's name.
public enum TextOperator: String, Codable, Sendable, CaseIterable {
    case `is`
    case isNot
    case contains
    case doesNotContain
    case startsWith
    case endsWith
    /// A regular expression, searched anywhere in the name (advanced mode).
    case matchesPattern
}

/// A condition on the file's name, without its extension.
public struct NameCondition: Codable, Sendable, Equatable {
    public var `operator`: TextOperator
    public var value: String
    public var caseSensitive: Bool

    public init(operator: TextOperator, value: String, caseSensitive: Bool = false) {
        self.operator = `operator`
        self.value = value
        self.caseSensitive = caseSensitive
    }
}

public enum ExtensionOperator: String, Codable, Sendable, CaseIterable {
    case `is`
    case isNot
    case isOneOf
}

/// A condition on the file's extension. Values are compared without case and
/// without a leading dot, so "PDF", ".pdf" and "pdf" are the same.
public struct ExtensionCondition: Codable, Sendable, Equatable {
    public var `operator`: ExtensionOperator
    public var values: [String]

    public init(operator: ExtensionOperator, values: [String]) {
        self.operator = `operator`
        self.values = values
    }
}

/// One test a file must pass.
public indirect enum Condition: Sendable, Equatable {
    case name(NameCondition)
    case fileExtension(ExtensionCondition)
    case kind(KindCondition)
    case size(SizeCondition)
    case date(DateCondition)
    case tags(TagCondition)
    case downloadSource(DownloadSourceCondition)
    case screenshot(ScreenshotCondition)
    /// A nested group, for "this AND (that OR the other)".
    case group(ConditionGroup)
}

/// Conditions combined with ALL or ANY.
public struct ConditionGroup: Codable, Sendable, Equatable {
    public enum Match: String, Codable, Sendable, CaseIterable {
        case all
        case any
    }

    public var match: Match
    public var conditions: [Condition]

    public init(match: Match, conditions: [Condition]) {
        self.match = match
        self.conditions = conditions
    }
}

// MARK: - Coding

/// Conditions are stored with a `type` field so the format stays readable and
/// can grow new kinds of condition without breaking existing files.
extension Condition: Codable {
    private enum Kind: String, Codable {
        case name
        case `extension`
        case kind
        case size
        case date
        case tags
        case downloadSource
        case screenshot
        case group
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .name:
            self = .name(try NameCondition(from: decoder))
        case .extension:
            self = .fileExtension(try ExtensionCondition(from: decoder))
        case .kind:
            self = .kind(try KindCondition(from: decoder))
        case .size:
            self = .size(try SizeCondition(from: decoder))
        case .date:
            self = .date(try DateCondition(from: decoder))
        case .tags:
            self = .tags(try TagCondition(from: decoder))
        case .downloadSource:
            self = .downloadSource(try DownloadSourceCondition(from: decoder))
        case .screenshot:
            self = .screenshot(try ScreenshotCondition(from: decoder))
        case .group:
            self = .group(try ConditionGroup(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .name(let condition):
            try container.encode(Kind.name, forKey: .type)
            try condition.encode(to: encoder)
        case .fileExtension(let condition):
            try container.encode(Kind.extension, forKey: .type)
            try condition.encode(to: encoder)
        case .kind(let condition):
            try container.encode(Kind.kind, forKey: .type)
            try condition.encode(to: encoder)
        case .size(let condition):
            try container.encode(Kind.size, forKey: .type)
            try condition.encode(to: encoder)
        case .date(let condition):
            try container.encode(Kind.date, forKey: .type)
            try condition.encode(to: encoder)
        case .tags(let condition):
            try container.encode(Kind.tags, forKey: .type)
            try condition.encode(to: encoder)
        case .downloadSource(let condition):
            try container.encode(Kind.downloadSource, forKey: .type)
            try condition.encode(to: encoder)
        case .screenshot(let condition):
            try container.encode(Kind.screenshot, forKey: .type)
            try condition.encode(to: encoder)
        case .group(let group):
            try container.encode(Kind.group, forKey: .type)
            try group.encode(to: encoder)
        }
    }
}
