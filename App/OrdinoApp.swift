import AppKit
import SwiftUI

/// Ordino lives in the menu bar. `LSUIElement` keeps it out of the Dock.
@main
struct OrdinoApp: App {
    @State private var model: AppModel
    private let logWindow: LogWindow

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        logWindow = LogWindow(model: model)
        Task { await model.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model, showLog: logWindow.show)
        } label: {
            Image("MenuBarIcon")
                .accessibilityLabel(Text("Ordino"))
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    let model: AppModel
    let showLog: () -> Void

    var body: some View {
        switch model.folderState {
        case .none:
            Text("No folder watched yet")
        case .watching(let url):
            Text("Watching “\(url.lastPathComponent)”")
        case .needsAccess(let path):
            Text("Access to “\(URL(fileURLWithPath: path).lastPathComponent)” is needed")
        case .failed(let message):
            Text(message)
        }

        Button(chooseTitle) {
            Task { await model.chooseFolder() }
        }

        if case .watching = model.folderState {
            Divider()
            if let destination = model.testRuleDestination {
                Text("Test rule: PDFs → “\(URL(fileURLWithPath: destination.displayPath).lastPathComponent)”")
            } else {
                Text("Test rule: choose where PDFs go")
            }
            Button(model.testRuleDestination == nil ? "Choose Destination for PDFs…" : "Change Destination for PDFs…") {
                Task { await model.chooseTestRuleDestination() }
            }
        }

        Button("Show Activity Log") {
            showLog()
        }
        .keyboardShortcut("l")

        Divider()

        Button("Quit Ordino") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var chooseTitle: LocalizedStringKey {
        switch model.folderState {
        case .needsAccess: "Choose Folder Again…"
        case .watching: "Watch a Different Folder…"
        case .none, .failed: "Watch Folder…"
        }
    }
}
