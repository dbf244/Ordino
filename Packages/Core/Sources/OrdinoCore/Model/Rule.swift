import Foundation

/// A folder the user granted access to, referenced by the id of its saved
/// bookmark (`StoredFolder.id`). The path is only for display.
public struct FolderReference: Codable, Sendable, Equatable, Hashable {
    public var folderID: UUID
    public var displayPath: String

    public init(folderID: UUID, displayPath: String) {
        self.folderID = folderID
        self.displayPath = displayPath
    }
}

/// Something a rule does to a matching file.
public enum RuleAction: Sendable, Equatable {
    /// Move the file into a folder. Name conflicts get a number (`test 2.pdf`);
    /// nothing is ever overwritten.
    case move(to: FolderReference)
}

/// In this folder → if these conditions match → do these actions.
public struct Rule: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var conditions: ConditionGroup
    /// Run in order. If one fails, the rest are skipped.
    public var actions: [RuleAction]
    /// "Keep checking other rules": when false, the first matching rule is the only one that runs.
    public var continuesToNextRule: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool,
        conditions: ConditionGroup,
        actions: [RuleAction],
        continuesToNextRule: Bool
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.conditions = conditions
        self.actions = actions
        self.continuesToNextRule = continuesToNextRule
    }
}

// MARK: - Coding

extension RuleAction: Codable {
    private enum Kind: String, Codable {
        case move
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case destination
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .move:
            self = .move(to: try container.decode(FolderReference.self, forKey: .destination))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let destination):
            try container.encode(Kind.move, forKey: .type)
            try container.encode(destination, forKey: .destination)
        }
    }
}
