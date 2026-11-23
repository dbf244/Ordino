import AppKit

/// The only way Ordino gets access to a folder: the user picks it.
@MainActor
enum FolderPicker {
    static func chooseFolder(startingAt directory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Watch")
        panel.message = String(localized: "Choose a folder for Ordino to watch.")
        if let directory {
            panel.directoryURL = directory
        }
        NSApp.activate()
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func explainProtected(_ url: URL) {
        showAlert(
            title: String(localized: "Ordino can't watch “\(url.lastPathComponent)”"),
            message: String(localized: "To keep your Mac safe, Ordino never watches system folders or your Library folder. Choose a folder like Downloads or Desktop instead.")
        )
    }

    static func explainFailure(_ url: URL) {
        showAlert(
            title: String(localized: "Ordino couldn't get access to “\(url.lastPathComponent)”"),
            message: String(localized: "Please try choosing the folder again.")
        )
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
    }
}
