import Foundation
import OrdinoCore
import Testing

@Suite("FileMover")
struct FileMoverTests {
    let source: TemporaryFolder
    let destination: TemporaryFolder

    init() throws {
        source = try TemporaryFolder()
        destination = try TemporaryFolder()
    }

    func contents(_ url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    @Test("A file is moved into the destination with its name")
    func simpleMove() throws {
        let file = try source.write("test.pdf", bytes: 10)
        let moved = try FileMover.move(file, into: destination.url)
        #expect(moved.lastPathComponent == "test.pdf")
        #expect(moved.deletingLastPathComponent().path == destination.url.path)
        #expect(FileManager.default.fileExists(atPath: moved.path))
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A name conflict adds a number; nothing is overwritten")
    func conflictAddsNumber() throws {
        let existing = try destination.write("test.pdf", bytes: 3)
        let file = try source.write("test.pdf", bytes: 10)

        let moved = try FileMover.move(file, into: destination.url)

        #expect(moved.lastPathComponent == "test 2.pdf")
        #expect(try contents(existing).count == 3, "The existing file must be untouched")
        #expect(try contents(moved).count == 10)
    }

    @Test("Numbers keep counting up past existing copies")
    func conflictCountsUp() throws {
        try destination.write("test.pdf")
        try destination.write("test 2.pdf")
        try destination.write("test 3.pdf")
        let moved = try FileMover.move(try source.write("test.pdf"), into: destination.url)
        #expect(moved.lastPathComponent == "test 4.pdf")
    }

    @Test("Conflict names for unusual names", arguments: [
        ("Makefile", "Makefile 2"),
        ("archive.tar.gz", "archive.tar 2.gz"),
        ("Chapter 2.pdf", "Chapter 2 2.pdf"),
        ("notes.", "notes. 2"),
    ])
    func conflictNames(name: String, expected: String) throws {
        try destination.write(name)
        let moved = try FileMover.move(try source.write(name), into: destination.url)
        #expect(moved.lastPathComponent == expected)
    }

    @Test("Folders are moved with their contents, and conflicts are numbered")
    func folders() throws {
        try destination.makeFolder("Album")
        let album = try source.makeFolder("Album")
        try Data([1, 2, 3]).write(to: album.appendingPathComponent("photo.jpg"))

        let moved = try FileMover.move(album, into: destination.url)

        #expect(moved.lastPathComponent == "Album 2")
        #expect(FileManager.default.fileExists(atPath: moved.appendingPathComponent("photo.jpg").path))
    }

    @Test("Candidate names follow the documented pattern")
    func candidateNames() {
        #expect(FileMover.candidateName(for: "test.pdf", attempt: 1) == "test.pdf")
        #expect(FileMover.candidateName(for: "test.pdf", attempt: 2) == "test 2.pdf")
        #expect(FileMover.candidateName(for: "test.pdf", attempt: 10) == "test 10.pdf")
        #expect(FileMover.candidateName(for: "Makefile", attempt: 3) == "Makefile 3")
    }

    @Test("A missing source is an error")
    func missingSource() {
        let ghost = source.url.appendingPathComponent("ghost.pdf")
        #expect(throws: FileMoverError.sourceMissing(ghost.path)) {
            try FileMover.move(ghost, into: destination.url)
        }
    }

    @Test("A missing destination is an error and the file stays where it was")
    func missingDestination() throws {
        let file = try source.write("test.pdf")
        let nowhere = destination.url.appendingPathComponent("Nowhere", isDirectory: true)
        #expect(throws: FileMoverError.destinationMissing(nowhere.path)) {
            try FileMover.move(file, into: nowhere)
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A destination that is a file is an error")
    func destinationIsFile() throws {
        let file = try source.write("test.pdf")
        let notFolder = try destination.write("not-a-folder")
        #expect(throws: FileMoverError.destinationMissing(notFolder.path)) {
            try FileMover.move(file, into: notFolder)
        }
    }

    @Test("Moving into the folder the file is already in does nothing")
    func alreadyThere() throws {
        let file = try source.write("test.pdf")
        #expect(throws: FileMoverError.alreadyInDestination(file.path)) {
            try FileMover.move(file, into: source.url)
        }
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("A folder cannot be moved into itself")
    func intoItself() throws {
        let folder = try source.makeFolder("Box")
        let inside = folder.appendingPathComponent("Inner", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        #expect(throws: FileMoverError.destinationInsideSource(folder.path)) {
            try FileMover.move(folder, into: inside)
        }
    }
}
