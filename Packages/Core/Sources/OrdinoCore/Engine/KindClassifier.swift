import Foundation
import UniformTypeIdentifiers

/// Sorts items into the kinds people think in, from the extension.
///
/// Uses the system's Uniform Type Identifiers first, then a short list of
/// common extensions the system may not know (for example .rar or .7z when no
/// app that opens them is installed).
enum KindClassifier {
    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg"]
    static let archiveExtensions: Set<String> = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "lz", "cab"]
    static let documentExtensions: Set<String> = [
        "pdf", "txt", "rtf", "rtfd", "md", "csv", "tsv", "json", "xml", "html", "epub",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp",
        "pages", "numbers", "key",
    ]
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "svg", "raw", "dng", "avif"]
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v", "avi", "mkv", "webm", "wmv", "mpg", "mpeg"]
    static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "opus", "caf"]

    static func kind(forExtension ext: String, isDirectory: Bool) -> FileKind {
        if ext == "app" { return .application }
        if isDirectory {
            // Only bundles the system declares (.rtfd, .pages…) take a kind from
            // their extension; any other folder is a folder, whatever its name.
            guard !ext.isEmpty,
                  let package = UTType(filenameExtension: ext, conformingTo: .package),
                  !package.isDynamic
            else { return .folder }
            return kind(of: package) ?? .folder
        }
        if installerExtensions.contains(ext) { return .installer }

        if !ext.isEmpty, let type = UTType(filenameExtension: ext), let kind = kind(of: type) {
            return kind
        }

        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if archiveExtensions.contains(ext) { return .archive }
        if documentExtensions.contains(ext) { return .document }
        return .other
    }

    private static func kind(of type: UTType) -> FileKind? {
        if type.conforms(to: .application) || type.conforms(to: .applicationBundle) { return .application }
        if type.conforms(to: .diskImage) { return .installer }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .archive) { return .archive }
        if isDocument(type) { return .document }
        return nil
    }

    private static func isDocument(_ type: UTType) -> Bool {
        let documents: [UTType] = [.pdf, .text, .rtf, .rtfd, .presentation, .spreadsheet, .epub, .compositeContent]
        return documents.contains { type.conforms(to: $0) }
    }
}
