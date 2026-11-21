import XCTest

/// Drives the real app through its menu bar item.
/// UI tests need XCTest: Swift Testing does not support XCUIApplication.
final class MenuBarUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuBarItemOffersQuitAndQuitTerminatesTheApp() {
        let app = XCUIApplication()
        app.launch()

        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "The menu bar item should appear")

        statusItem.click()

        // Scope to the status item's own menu: SwiftUI also builds a hidden
        // app menu with its own "Quit Ordino" item.
        let quit = statusItem.menuItems["Quit Ordino"]
        XCTAssertTrue(quit.waitForExistence(timeout: 5), "The menu should contain Quit Ordino")

        quit.click()

        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "Quit should terminate the app")
    }
}
