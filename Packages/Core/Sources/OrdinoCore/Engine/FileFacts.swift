import Foundation

/// What the Evaluator knows about a file. Gathered once, then every rule is
/// checked against the same facts, so evaluation is pure and repeatable.
public struct FileFacts: Sendable, Equatable {
    public let url: URL
    /// The name without its extension: `Invoice_0042` for `Invoice_0042.pdf`.
    public let name: String
    /// Lowercased, without the dot; empty when there is none.
    public let fileExtension: String
    public let isDirectory: Bool

    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
        let fullName = url.lastPathComponent
        let ext = url.pathExtension
        if ext.isEmpty {
            name = fullName
        } else {
            name = String(fullName.dropLast(ext.count + 1))
        }
        fileExtension = ext.lowercased()
    }

    /// Reads the facts from disk, or `nil` if the item no longer exists.
    public static func read(_ url: URL) -> FileFacts? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return FileFacts(url: url, isDirectory: attributes[.type] as? FileAttributeType == .typeDirectory)
    }
}
