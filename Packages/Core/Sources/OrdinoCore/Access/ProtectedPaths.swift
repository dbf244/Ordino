import Foundation

/// Folders Ordino must never watch or touch: the system, `/`, and `~/Library`.
public enum ProtectedPaths {
    /// Top-level system locations. Everything inside them is protected too.
    static let systemRoots = [
        "/System", "/Library", "/usr", "/bin", "/sbin",
        "/private", "/etc", "/var", "/tmp", "/dev", "/cores", "/opt",
    ]

    /// The user's real home folder. Inside the App Sandbox, `NSHomeDirectory()`
    /// points at the app's container, so this asks the user database instead.
    public static var userHomeDirectory: URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    /// Whether `url` is `/`, a system location, or the user's Library (or inside one).
    /// Comparison ignores case, like the default APFS volume.
    public static func isProtected(_ url: URL, home: URL = userHomeDirectory) -> Bool {
        let path = normalized(url.path)
        if path == "/" { return true }
        let roots = systemRoots + [normalized(home.path) + "/Library"]
        return roots.contains { root in
            let root = root.lowercased()
            return path == root || path.hasPrefix(root + "/")
        }
    }

    private static func normalized(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        let trimmed = standardized.count > 1 && standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
        return trimmed.lowercased()
    }
}
