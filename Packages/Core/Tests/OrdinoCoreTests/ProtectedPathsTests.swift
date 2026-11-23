import Foundation
import OrdinoCore
import Testing

@Suite("ProtectedPaths")
struct ProtectedPathsTests {
    let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)

    @Test("System locations are protected", arguments: [
        "/",
        "/System",
        "/System/Library/CoreServices",
        "/Library",
        "/Library/Application Support",
        "/usr/local",
        "/bin",
        "/sbin",
        "/private",
        "/private/etc",
        "/etc",
        "/var",
        "/dev",
        "/system",
        "/LIBRARY/Caches",
    ])
    func systemLocationsAreProtected(path: String) {
        #expect(ProtectedPaths.isProtected(URL(fileURLWithPath: path), home: home))
    }

    @Test("The user's Library is protected", arguments: [
        "/Users/someone/Library",
        "/Users/someone/Library/Mobile Documents",
        "/Users/someone/library/Containers",
    ])
    func userLibraryIsProtected(path: String) {
        #expect(ProtectedPaths.isProtected(URL(fileURLWithPath: path), home: home))
    }

    @Test("Ordinary user folders are not protected", arguments: [
        "/Users/someone/Downloads",
        "/Users/someone/Desktop",
        "/Users/someone/Ordino-Playground",
        "/Users/someone/Documents/Library Books",
        "/Users/someone/LibraryStuff",
        "/Users/someone",
        "/Volumes/External/Photos",
        "/Applications Extra",
    ])
    func userFoldersAreNotProtected(path: String) {
        #expect(!ProtectedPaths.isProtected(URL(fileURLWithPath: path), home: home))
    }

    @Test("Paths are checked after resolving .. components")
    func dotDotIsResolved() {
        let sneaky = URL(fileURLWithPath: "/Users/someone/Downloads/../Library")
        #expect(ProtectedPaths.isProtected(sneaky, home: home))
    }

    @Test("The real home folder is found even though tests are not sandboxed")
    func realHomeDirectory() {
        let home = ProtectedPaths.userHomeDirectory.path
        #expect(home.hasPrefix("/"))
        #expect(!home.contains("/Library/Containers/"))
    }
}
