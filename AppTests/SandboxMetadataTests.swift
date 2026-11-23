import Foundation
import OrdinoCore
import Testing

/// Core's tests run outside the sandbox. These run inside the sandboxed app,
/// to prove every fact a condition needs can still be read there.
@Suite("Metadata inside the sandbox")
struct SandboxMetadataTests {
    @Test("Tags, dates, download source, screenshot flag and last opened are readable")
    func readsEverything() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let file = folder.appendingPathComponent("Screenshot.png")
        try Data(count: 1_234).write(to: file)
        try (file as NSURL).setResourceValue(["Red"], forKey: .tagNamesKey)
        try setAttribute("com.apple.metadata:kMDItemWhereFroms", plist(["https://www.apple.com/x.png"]), on: file)
        try setAttribute("com.apple.metadata:kMDItemIsScreenCapture", plist(true), on: file)
        var opened = timespec(tv_sec: 1_700_000_000, tv_nsec: 0)
        try setAttribute("com.apple.lastuseddate#PS", Data(bytes: &opened, count: MemoryLayout<timespec>.size), on: file)

        let facts = try #require(FileFacts.read(file))

        #expect(facts.kind == .image)
        #expect(facts.size == 1_234)
        #expect(facts.tags == ["Red"])
        #expect(facts.whereFroms == ["https://www.apple.com/x.png"])
        #expect(facts.isScreenshot == true)
        #expect(facts.lastOpenedDate == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(facts.dateAdded != nil)
        #expect(facts.creationDate != nil)
        #expect(facts.modificationDate != nil)
    }

    private func plist(_ value: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    private func setAttribute(_ name: String, _ data: Data, on file: URL) throws {
        let result = data.withUnsafeBytes { setxattr(file.path, name, $0.baseAddress, $0.count, 0, 0) }
        guard result == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
