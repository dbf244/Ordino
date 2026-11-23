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

    @Test("App runs inside the App Sandbox with only user-chosen folder access", arguments: [
        "com.apple.security.app-sandbox",
        "com.apple.security.files.user-selected.read-write",
        "com.apple.security.files.bookmarks.app-scope",
    ])
    func hasEntitlement(_ name: String) throws {
        let task = try #require(SecTaskCreateFromSelf(nil))
        let value = SecTaskCopyValueForEntitlement(task, name as CFString, nil)
        #expect(value as? Bool == true)
    }

    @Test("App has no network access", arguments: [
        "com.apple.security.network.client",
        "com.apple.security.network.server",
    ])
    func hasNoNetwork(_ name: String) throws {
        let task = try #require(SecTaskCreateFromSelf(nil))
        #expect(SecTaskCopyValueForEntitlement(task, name as CFString, nil) == nil)
    }

    @Test("Menu bar icon is in the asset catalog")
    func menuBarIconExists() {
        #expect(Bundle.main.image(forResource: "MenuBarIcon") != nil)
    }
}
