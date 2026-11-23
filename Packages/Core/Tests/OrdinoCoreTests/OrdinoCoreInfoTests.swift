import OrdinoCore
import Testing

@Suite("OrdinoCoreInfo")
struct OrdinoCoreInfoTests {
    @Test("Version is the current release")
    func versionIsCurrentRelease() {
        #expect(OrdinoCoreInfo.version == "0.2.0")
    }

    @Test("Version is plain semantic versioning (MAJOR.MINOR.PATCH)")
    func versionIsSemanticVersion() {
        let parts = OrdinoCoreInfo.version.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { part in !part.isEmpty && part.allSatisfy(\.isASCIIDigit) })
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
