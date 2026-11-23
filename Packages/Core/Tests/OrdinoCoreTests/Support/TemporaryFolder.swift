import Foundation

/// A real folder on disk that is deleted when the test ends.
final class TemporaryFolder: Sendable {
    let url: URL

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrdinoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        // FSEvents reports canonical paths (/private/var/...), so tests use them too.
        url = URL(fileURLWithPath: base.path.canonicalPath, isDirectory: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func write(_ name: String, bytes: Int = 16) throws -> URL {
        let file = url.appendingPathComponent(name)
        try Data(repeating: 0x2A, count: bytes).write(to: file)
        return file
    }

    @discardableResult
    func makeFolder(_ name: String) throws -> URL {
        let folder = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Appends `chunks` pieces of `chunkSize` bytes with a pause between them,
    /// like a slow copy or download.
    func writeSlowly(_ name: String, chunks: Int, chunkSize: Int, pause: Duration) async throws -> URL {
        let file = url.appendingPathComponent(name)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        for _ in 0..<chunks {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(repeating: 0x2A, count: chunkSize))
            try handle.synchronize()
            try await Task.sleep(for: pause)
        }
        return file
    }
}

private extension String {
    var canonicalPath: String {
        guard let resolved = realpath(self, nil) else { return self }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
