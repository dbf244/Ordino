import Foundation
import OrdinoCore
import Testing

@Suite("FileFilter")
struct FileFilterTests {
    @Test("Partial downloads are ignored", arguments: [
        "movie.mp4.crdownload",
        "Report.pdf.download",
        "archive.zip.part",
        "UPPER.ZIP.PART",
        "Unconfirmed 123.crdownload",
    ])
    func partialDownloadsAreIgnored(name: String) {
        #expect(FileFilter.isIgnored(URL(fileURLWithPath: "/tmp/\(name)")))
    }

    @Test("Hidden files are ignored", arguments: [".DS_Store", ".localized", ".hidden.txt"])
    func hiddenFilesAreIgnored(name: String) {
        #expect(FileFilter.isIgnored(URL(fileURLWithPath: "/tmp/\(name)")))
    }

    @Test("Regular files are not ignored", arguments: [
        "invoice.pdf",
        "photo.heic",
        "notes",
        "partial.txt",
        "download.pdf",
        "my.part.of.it.txt",
        "Folder",
    ])
    func regularFilesAreNotIgnored(name: String) {
        #expect(!FileFilter.isIgnored(URL(fileURLWithPath: "/tmp/\(name)")))
    }
}
