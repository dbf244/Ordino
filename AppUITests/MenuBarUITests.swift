import XCTest

/// Drives the real app through its menu bar item.
/// UI tests need XCTest: Swift Testing does not support XCUIApplication.
final class MenuBarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openMenu(_ app: XCUIApplication) -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "The menu bar item should appear")
        statusItem.click()
        return statusItem
    }

    @MainActor
    func testMenuOffersFolderChoiceAndLog() {
        let app = XCUIApplication()
        app.launch()
        let statusItem = openMenu(app)

        let chooseTitles = ["Watch Folder…", "Watch a Different Folder…", "Choose Folder Again…"]
        let choose = statusItem.menuItems.matching(NSPredicate(format: "title IN %@", chooseTitles)).firstMatch
        XCTAssertTrue(choose.waitForExistence(timeout: 5), "The menu should offer to choose a folder")
        XCTAssertTrue(statusItem.menuItems["Show Activity Log"].exists)

        app.typeKey(.escape, modifierFlags: [])
        app.terminate()
    }

    @MainActor
    func testShowActivityLogOpensTheLogWindow() {
        let app = XCUIApplication()
        app.launch()
        let statusItem = openMenu(app)

        statusItem.menuItems["Show Activity Log"].click()

        XCTAssertTrue(app.windows["Activity Log"].waitForExistence(timeout: 5), "The log window should open")
        app.terminate()
    }

    @MainActor
    func testQuitTerminatesTheApp() {
        let app = XCUIApplication()
        app.launch()
        let statusItem = openMenu(app)

        // Scope to the status item's own menu: SwiftUI also builds a hidden
        // app menu with its own "Quit Ordino" item.
        let quit = statusItem.menuItems["Quit Ordino"]
        XCTAssertTrue(quit.waitForExistence(timeout: 5), "The menu should contain Quit Ordino")
        quit.click()

        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Quit should terminate the app")
    }
}
