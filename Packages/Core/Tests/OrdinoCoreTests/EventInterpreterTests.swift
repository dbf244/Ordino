import Foundation
@testable import OrdinoCore
import Testing

/// The interpreter is pure: it turns raw FSEvents records into changes, using
/// an injected "does this path exist now?" check instead of the disk.
@Suite("EventInterpreter")
struct EventInterpreterTests {
    let root = "/Users/someone/Playground"

    func interpret(_ records: [FSEventRecord], existing: Set<String>) -> [WatchChange] {
        EventInterpreter(rootPath: root).interpret(records) { existing.contains($0) }
    }

    func record(_ name: String, _ flags: FSEventFlags, fileID: UInt64? = nil, id: UInt64 = 1) -> FSEventRecord {
        FSEventRecord(path: name.isEmpty ? root : "\(root)/\(name)", flags: flags, fileID: fileID, eventID: id)
    }

    func url(_ name: String) -> URL {
        URL(fileURLWithPath: "\(root)/\(name)")
    }

    @Test("A new file is a candidate")
    func createdFile() {
        let changes = interpret([record("a.pdf", [.itemCreated, .itemIsFile])], existing: ["\(root)/a.pdf"])
        #expect(changes == [.candidate(url("a.pdf"))])
    }

    @Test("A modified file is a candidate")
    func modifiedFile() {
        let changes = interpret([record("a.pdf", [.itemModified, .itemIsFile])], existing: ["\(root)/a.pdf"])
        #expect(changes == [.candidate(url("a.pdf"))])
    }

    @Test("A deleted file is removed")
    func deletedFile() {
        let changes = interpret([record("a.pdf", [.itemRemoved, .itemIsFile])], existing: [])
        #expect(changes == [.removed(url("a.pdf"))])
    }

    @Test("Created and deleted in one batch is reported as removed, not as a candidate")
    func createdThenDeleted() {
        let changes = interpret([record("a.pdf", [.itemCreated, .itemRemoved, .itemIsFile])], existing: [])
        #expect(changes == [.removed(url("a.pdf"))])
    }

    @Test("A rename inside the folder is paired by file ID")
    func renameInsideFolder() {
        let changes = interpret([
            record("old.pdf", [.itemRenamed, .itemIsFile], fileID: 42, id: 1),
            record("new.pdf", [.itemRenamed, .itemIsFile], fileID: 42, id: 2),
        ], existing: ["\(root)/new.pdf"])
        #expect(changes == [.renamed(from: url("old.pdf"), to: url("new.pdf"))])
    }

    @Test("Moving a file out of the folder (e.g. to the Trash) is a removal")
    func movedOut() {
        let changes = interpret([
            record("a.pdf", [.itemRenamed, .itemIsFile], fileID: 7, id: 1),
            FSEventRecord(path: "/Users/someone/.Trash/a.pdf", flags: [.itemRenamed, .itemIsFile], fileID: 7, eventID: 2),
        ], existing: ["/Users/someone/.Trash/a.pdf"])
        #expect(changes == [.removed(url("a.pdf"))])
    }

    @Test("Moving a file into the folder is a candidate")
    func movedIn() {
        let changes = interpret([
            FSEventRecord(path: "/Users/someone/Desktop/a.pdf", flags: [.itemRenamed, .itemIsFile], fileID: 9, eventID: 1),
            record("a.pdf", [.itemRenamed, .itemIsFile], fileID: 9, id: 2),
        ], existing: ["\(root)/a.pdf"])
        #expect(changes == [.candidate(url("a.pdf"))])
    }

    @Test("A finished download renamed from .crdownload is a candidate, not a rename")
    func finishedDownload() {
        let changes = interpret([
            record("movie.mp4.crdownload", [.itemRenamed, .itemIsFile], fileID: 5, id: 1),
            record("movie.mp4", [.itemRenamed, .itemIsFile], fileID: 5, id: 2),
        ], existing: ["\(root)/movie.mp4"])
        #expect(changes == [.candidate(url("movie.mp4"))])
    }

    @Test("Partial downloads and hidden files produce no changes")
    func ignoredFiles() {
        let changes = interpret([
            record("movie.mp4.crdownload", [.itemCreated, .itemIsFile]),
            record(".DS_Store", [.itemModified, .itemIsFile]),
            record("old.part", [.itemRemoved, .itemIsFile]),
        ], existing: ["\(root)/movie.mp4.crdownload", "\(root)/.DS_Store"])
        #expect(changes.isEmpty)
    }

    @Test("Files inside subfolders are never candidates; the subfolder itself counts")
    func onlyDirectChildren() {
        let changes = interpret([
            record("Sub/inner.txt", [.itemCreated, .itemIsFile]),
            record("Sub", [.itemCreated, .itemIsDir]),
        ], existing: ["\(root)/Sub", "\(root)/Sub/inner.txt"])
        #expect(changes == [.candidate(url("Sub"))])
    }

    @Test("Events deep inside a subfolder say once that the subfolder is still changing")
    func deepEventsMarkTheSubfolder() {
        let changes = interpret([
            record("Album/a.jpg", [.itemCreated, .itemIsFile], id: 1),
            record("Album/b.jpg", [.itemCreated, .itemIsFile], id: 2),
            record("Album/2026/c.jpg", [.itemModified, .itemIsFile], id: 3),
            record("Other/x/y/z.o", [.itemRemoved, .itemIsFile], id: 4),
        ], existing: ["\(root)/Album", "\(root)/Other"])
        #expect(changes == [.contentChanged(url("Album")), .contentChanged(url("Other"))])
    }

    @Test("A rename deep inside a subfolder marks the subfolder")
    func deepRename() {
        let changes = interpret([
            record("Album/old.jpg", [.itemRenamed, .itemIsFile], fileID: 9, id: 1),
            record("Album/new.jpg", [.itemRenamed, .itemIsFile], fileID: 9, id: 2),
        ], existing: ["\(root)/Album", "\(root)/Album/new.jpg"])
        #expect(changes == [.contentChanged(url("Album"))])
    }

    @Test("Events inside hidden folders or partial downloads say nothing")
    func deepEventsInIgnoredItems() {
        let changes = interpret([
            record(".git/objects/ab/cd", [.itemCreated, .itemIsFile], id: 1),
            record("Movie.download/data", [.itemModified, .itemIsFile], id: 2),
        ], existing: ["\(root)/.git", "\(root)/Movie.download"])
        #expect(changes.isEmpty)
    }

    @Test("Events outside the watched folder say nothing")
    func eventsOutsideRoot() {
        let changes = interpret([
            FSEventRecord(path: "\(root)-sibling/Album/a.jpg", flags: [.itemCreated, .itemIsFile], fileID: nil, eventID: 1),
            FSEventRecord(path: "/elsewhere/a/b.txt", flags: [.itemCreated, .itemIsFile], fileID: nil, eventID: 2),
        ], existing: [])
        #expect(changes.isEmpty)
    }

    @Test("Events on the watched folder itself are not candidates")
    func rootItself() {
        let changes = interpret([record("", [.itemModified, .itemIsDir])], existing: [root])
        #expect(changes.isEmpty)
    }

    @Test("Several events for one file in a batch give a single change")
    func coalescesPerPath() {
        let changes = interpret([
            record("a.pdf", [.itemCreated, .itemIsFile], id: 1),
            record("a.pdf", [.itemModified, .itemIsFile], id: 2),
            record("a.pdf", [.itemInodeMetaMod, .itemIsFile], id: 3),
        ], existing: ["\(root)/a.pdf"])
        #expect(changes == [.candidate(url("a.pdf"))])
    }

    @Test("Root moved or deleted is reported")
    func rootChanged() {
        let changes = interpret([record("", [.rootChanged])], existing: [])
        #expect(changes == [.rootChanged])
    }

    @Test("Dropped events ask for a rescan")
    func droppedEvents() {
        let changes = interpret([record("", [.mustScanSubDirs, .userDropped])], existing: [root])
        #expect(changes == [.rescan])
    }

    @Test("Changes keep the order the events happened in")
    func keepsOrder() {
        let changes = interpret([
            record("b.txt", [.itemRemoved, .itemIsFile], id: 1),
            record("a.txt", [.itemCreated, .itemIsFile], id: 2),
        ], existing: ["\(root)/a.txt"])
        #expect(changes == [.removed(url("b.txt")), .candidate(url("a.txt"))])
    }
}
