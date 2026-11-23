import Foundation

/// The broad kind of an item, as a person would describe it.
public enum FileKind: String, Codable, Sendable, CaseIterable {
    case image
    case video
    case audio
    case document
    case archive
    /// Disk images and installer packages (.dmg, .pkg, .mpkg).
    case installer
    case folder
    /// App bundles (.app). They are folders inside, but nobody thinks of them as folders.
    case application
    /// Anything else, including files without an extension.
    case other
}

public enum KindOperator: String, Codable, Sendable, CaseIterable {
    case `is`
    case isNot
}

public struct KindCondition: Codable, Sendable, Equatable {
    public var `operator`: KindOperator
    public var kind: FileKind

    public init(operator: KindOperator, kind: FileKind) {
        self.operator = `operator`
        self.kind = kind
    }
}

public enum SizeOperator: String, Codable, Sendable, CaseIterable {
    case greaterThan
    case lessThan
}

/// Decimal units, like Finder: 1 KB = 1,000 bytes.
public enum SizeUnit: String, Codable, Sendable, CaseIterable {
    case bytes
    case kilobytes
    case megabytes
    case gigabytes

    var multiplier: Double {
        switch self {
        case .bytes: 1
        case .kilobytes: 1_000
        case .megabytes: 1_000_000
        case .gigabytes: 1_000_000_000
        }
    }
}

/// Keeps the amount and unit the user typed, so an editor can show them back.
public struct SizeCondition: Codable, Sendable, Equatable {
    public var `operator`: SizeOperator
    public var amount: Double
    public var unit: SizeUnit

    public init(operator: SizeOperator, amount: Double, unit: SizeUnit) {
        self.operator = `operator`
        self.amount = amount
        self.unit = unit
    }

    public var bytes: Int64 {
        Int64((amount * unit.multiplier).rounded())
    }
}

public enum DateAttribute: String, Codable, Sendable, CaseIterable {
    case added
    case created
    case modified
    case lastOpened
}

public enum DateOperator: String, Codable, Sendable, CaseIterable {
    /// Older than: "added more than 3 days ago".
    case moreThan
    /// Newer than: "modified less than 1 week ago".
    case lessThan
}

public enum TimeUnit: String, Codable, Sendable, CaseIterable {
    case hours
    case days
    case weeks
    case months
    case years
}

public struct DateCondition: Codable, Sendable, Equatable {
    public var attribute: DateAttribute
    public var `operator`: DateOperator
    public var amount: Int
    public var unit: TimeUnit

    public init(attribute: DateAttribute, operator: DateOperator, amount: Int, unit: TimeUnit) {
        self.attribute = attribute
        self.operator = `operator`
        self.amount = amount
        self.unit = unit
    }
}

public enum TagOperator: String, Codable, Sendable, CaseIterable {
    case hasTag
    case doesNotHaveTag
    case hasNoTags
    case hasAnyTag
}

/// A Finder tag condition. `tag` is ignored by `hasNoTags` and `hasAnyTag`.
/// Tag names are compared without case.
public struct TagCondition: Codable, Sendable, Equatable {
    public var `operator`: TagOperator
    public var tag: String

    public init(operator: TagOperator, tag: String) {
        self.operator = `operator`
        self.tag = tag
    }
}

public enum SourceOperator: String, Codable, Sendable, CaseIterable {
    case isFrom
    case isNotFrom
}

/// Where a file was downloaded from (`kMDItemWhereFroms`). A domain also
/// matches its subdomains: `apple.com` matches `support.apple.com`.
public struct DownloadSourceCondition: Codable, Sendable, Equatable {
    public var `operator`: SourceOperator
    public var domain: String

    public init(operator: SourceOperator, domain: String) {
        self.operator = `operator`
        self.domain = domain
    }
}

/// Whether the file is a screenshot taken with macOS (`kMDItemIsScreenCapture`).
public struct ScreenshotCondition: Codable, Sendable, Equatable {
    public var isScreenshot: Bool

    public init(isScreenshot: Bool) {
        self.isScreenshot = isScreenshot
    }
}
