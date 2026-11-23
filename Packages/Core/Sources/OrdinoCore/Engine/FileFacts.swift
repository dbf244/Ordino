import Foundation

/// Facts that cost something to read. Only the ones a rule set uses are read.
public struct FactSet: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// For folders this walks everything inside, so it is only read when needed.
    public static let size = FactSet(rawValue: 1 << 0)
    public static let dates = FactSet(rawValue: 1 << 1)
    public static let lastOpened = FactSet(rawValue: 1 << 2)
    public static let tags = FactSet(rawValue: 1 << 3)
    public static let downloadSource = FactSet(rawValue: 1 << 4)
    public static let screenshot = FactSet(rawValue: 1 << 5)

    public static let all: FactSet = [.size, .dates, .lastOpened, .tags, .downloadSource, .screenshot]
}

/// What the Evaluator knows about a file. Gathered once, then every rule is
/// checked against the same facts, so evaluation is pure and repeatable.
///
/// Optional facts are `nil` when unknown (not read, or not recorded for this
/// file). Conditions on unknown facts never match.
public struct FileFacts: Sendable, Equatable {
    public let url: URL
    /// The name without its extension: `Invoice_0042` for `Invoice_0042.pdf`.
    public let name: String
    /// Lowercased, without the dot; empty when there is none.
    public let fileExtension: String
    public let isDirectory: Bool
    public let kind: FileKind
    /// In bytes; for folders, the total of everything inside.
    public let size: Int64?
    public let dateAdded: Date?
    public let creationDate: Date?
    public let modificationDate: Date?
    public let lastOpenedDate: Date?
    /// Finder tag names; empty when the file has none.
    public let tags: [String]?
    /// The URLs a browser recorded for a download; empty when not downloaded.
    public let whereFroms: [String]?
    public let isScreenshot: Bool?

    public init(
        url: URL,
        isDirectory: Bool,
        size: Int64? = nil,
        dateAdded: Date? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        lastOpenedDate: Date? = nil,
        tags: [String]? = nil,
        whereFroms: [String]? = nil,
        isScreenshot: Bool? = nil
    ) {
        self.url = url
        self.isDirectory = isDirectory
        let fullName = url.lastPathComponent
        let ext = url.pathExtension
        name = ext.isEmpty ? fullName : String(fullName.dropLast(ext.count + 1))
        fileExtension = ext.lowercased()
        kind = KindClassifier.kind(forExtension: fileExtension, isDirectory: isDirectory)
        self.size = size
        self.dateAdded = dateAdded
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.lastOpenedDate = lastOpenedDate
        self.tags = tags
        self.whereFroms = whereFroms
        self.isScreenshot = isScreenshot
    }

    /// Reads the facts from disk, or `nil` if the item no longer exists.
    /// Name, extension and kind are always available; the rest only if asked for.
    public static func read(_ url: URL, needing facts: FactSet = .all) -> FileFacts? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        let isDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
        var values: URLResourceValues?
        if !facts.isDisjoint(with: [.dates, .tags]) {
            // A fresh URL, so no cached values from an earlier read are reused.
            let fresh = URL(fileURLWithPath: url.path)
            values = try? fresh.resourceValues(forKeys: [.addedToDirectoryDateKey, .tagNamesKey])
        }
        let reader = MetadataReader(path: url.path)
        return FileFacts(
            url: url,
            isDirectory: isDirectory,
            size: facts.contains(.size) ? totalSize(url, attributes: attributes, isDirectory: isDirectory) : nil,
            dateAdded: facts.contains(.dates) ? values?.addedToDirectoryDate : nil,
            creationDate: facts.contains(.dates) ? attributes[.creationDate] as? Date : nil,
            modificationDate: facts.contains(.dates) ? attributes[.modificationDate] as? Date : nil,
            lastOpenedDate: facts.contains(.lastOpened) ? reader.lastOpened() : nil,
            tags: facts.contains(.tags) ? (values?.tagNames ?? []) : nil,
            whereFroms: facts.contains(.downloadSource) ? reader.whereFroms() : nil,
            isScreenshot: facts.contains(.screenshot) ? reader.isScreenshot() : nil
        )
    }

    private static func totalSize(_ url: URL, attributes: [FileAttributeKey: Any], isDirectory: Bool) -> Int64? {
        guard isDirectory else {
            return (attributes[.size] as? NSNumber)?.int64Value
        }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return nil
        }
        var total: Int64 = 0
        for case let item as URL in enumerator {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}

/// Reads the metadata macOS stores on the file itself: the same attributes
/// Spotlight indexes, read directly so it works in the sandbox, without
/// waiting for indexing, and on volumes Spotlight doesn't index.
struct MetadataReader {
    let path: String

    /// `kMDItemWhereFroms`: written by browsers on downloads. Empty if absent.
    func whereFroms() -> [String] {
        guard let data = attribute("com.apple.metadata:kMDItemWhereFroms"),
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [Any]
        else { return [] }
        return list.compactMap { $0 as? String }
    }

    /// `kMDItemIsScreenCapture`: written by macOS on screenshots. False if absent.
    func isScreenshot() -> Bool {
        guard let data = attribute("com.apple.metadata:kMDItemIsScreenCapture"),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return false }
        return (value as? Bool) ?? ((value as? NSNumber)?.boolValue ?? false)
    }

    /// When the file was last opened, as Launch Services records it. Nil if never.
    func lastOpened() -> Date? {
        guard let data = attribute("com.apple.lastuseddate#PS"), data.count >= MemoryLayout<timespec>.size else {
            return nil
        }
        let time = data.withUnsafeBytes { $0.loadUnaligned(as: timespec.self) }
        return Date(timeIntervalSince1970: Double(time.tv_sec) + Double(time.tv_nsec) / 1e9)
    }

    private func attribute(_ name: String) -> Data? {
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, length, 0, 0) }
        return read == length ? data : nil
    }
}
