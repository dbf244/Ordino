import Foundation

/// Decides which items Ordino never reacts to.
public enum FileFilter {
    /// Extensions browsers and download tools use while a file is still arriving.
    /// Safari uses `.download` bundles, Chrome `.crdownload`, Firefox and others `.part`.
    public static let partialDownloadExtensions: Set<String> = ["crdownload", "download", "part"]

    /// Whether the item should be ignored: a partial download, or a hidden
    /// item such as `.DS_Store`.
    public static func isIgnored(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }
        return partialDownloadExtensions.contains(url.pathExtension.lowercased())
    }
}
