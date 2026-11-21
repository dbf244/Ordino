import AppKit
import OrdinoCore
import Security
import Testing

/// These tests run hosted inside Ordino.app, so `Bundle.main` and the
/// current process are the app itself.
@Suite("App configuration")
struct AppConfigurationTests {
    @Test("Marketing version matches OrdinoCore")
    func marketingVersionMatchesCore() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        #expect(version == OrdinoCoreInfo.version)
    }

    @Test("Bundle identifier is the App Store identifier")
    func bundleIdentifier() {
        #expect(Bundle.main.bundleIdentifier == "io.github.dbf244.Ordino")
    }

    @Test("App is an agent: menu bar only, no Dock icon")
    func isMenuBarOnly() {
        let isAgent = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool
        #expect(isAgent == true)
    }

    @Test("App runs inside the App Sandbox")
    func isSandboxed() throws {
        let task = try #require(SecTaskCreateFromSelf(nil))
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.app-sandbox" as CFString, nil)
        #expect(value as? Bool == true)
    }

    @Test("Menu bar icon is in the asset catalog")
    func menuBarIconExists() {
        #expect(Bundle.main.image(forResource: "MenuBarIcon") != nil)
    }
}
