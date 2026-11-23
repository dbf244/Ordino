import AppKit
import SwiftUI

/// The activity log window. Managed with AppKit so it only opens when asked:
/// a SwiftUI `Window` scene would open by itself at launch on macOS 14.
@MainActor
final class LogWindow {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: ActivityLogView(model: model)))
        window.title = String(localized: "Activity Log")
        window.setContentSize(NSSize(width: 480, height: 520))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("ActivityLog")
        if !window.setFrameUsingName("ActivityLog") {
            window.center()
        }
        return window
    }
}
