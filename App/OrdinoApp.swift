import AppKit
import SwiftUI

/// Ordino lives in the menu bar. `LSUIElement` keeps it out of the Dock.
@main
struct OrdinoApp: App {
    var body: some Scene {
        MenuBarExtra {
            Button("Quit Ordino") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel(Text("Ordino"))
        }
        .menuBarExtraStyle(.menu)
    }
}
