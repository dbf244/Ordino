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
public enum Condition: Sendable, Equatable {
    case name(NameCondition)
    case fileExtension(ExtensionCondition)
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
        }
    }
}
