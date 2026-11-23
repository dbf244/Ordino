import Foundation

/// Writes the same metadata macOS writes, so tests use real files with real
/// attributes instead of mocks.
enum FileMetadata {
    /// What Safari, Chrome and other browsers record as the download source.
    static func setWhereFroms(_ urls: [String], on file: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: urls, format: .binary, options: 0)
        try setAttribute("com.apple.metadata:kMDItemWhereFroms", data, on: file)
    }

    /// What `screencapture` (⌘⇧3 / ⌘⇧4 / ⌘⇧5) records on a screenshot.
    static func markAsScreenshot(_ file: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        try setAttribute("com.apple.metadata:kMDItemIsScreenCapture", data, on: file)
    }

    /// What Launch Services records when a file is opened.
    static func setLastOpened(_ date: Date, on file: URL) throws {
        let seconds = Int64(date.timeIntervalSince1970)
        var value = timespec(tv_sec: Int(seconds), tv_nsec: 0)
        let data = Data(bytes: &value, count: MemoryLayout<timespec>.size)
        try setAttribute("com.apple.lastuseddate#PS", data, on: file)
    }

    /// Finder tags, set the way Finder sets them.
    static func setTags(_ tags: [String], on file: URL) throws {
        try (file as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }

    static func setDates(created: Date, modified: Date, on file: URL) throws {
        try FileManager.default.setAttributes(
            [.creationDate: created, .modificationDate: modified],
            ofItemAtPath: file.path
        )
    }

    private static func setAttribute(_ name: String, _ data: Data, on file: URL) throws {
        let result = data.withUnsafeBytes { buffer in
            setxattr(file.path, name, buffer.baseAddress, buffer.count, 0, 0)
        }
        guard result == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
