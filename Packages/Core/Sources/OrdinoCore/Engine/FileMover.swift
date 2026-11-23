import Darwin
import Foundation

public enum FileMoverError: Error, Sendable, Hashable {
    case sourceMissing(String)
    case destinationMissing(String)
    /// The item is already in the destination folder.
    case alreadyInDestination(String)
    /// A folder cannot be moved into itself or one of its subfolders.
    case destinationInsideSource(String)
    /// Every candidate name up to `FileMover.maximumAttempts` was taken.
    case noFreeName(String)
    case moveFailed(String)
}

/// Moves items without ever overwriting anything.
///
/// If the name is taken, a number is added before the extension: `test.pdf`,
/// `test 2.pdf`, `test 3.pdf`… A number the user put in the name is never
/// changed (`Chapter 2.pdf` becomes `Chapter 2 2.pdf`). Each attempt is an
/// exclusive rename, so a file appearing at the same moment is never replaced.
public enum FileMover {
    public static let maximumAttempts = 10_000

    /// The name to try on `attempt` (1 is the original name).
    public static func candidateName(for name: String, attempt: Int) -> String {
        guard attempt > 1 else { return name }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty else { return "\(name) \(attempt)" }
        let base = String(name.dropLast(ext.count + 1))
        return "\(base) \(attempt).\(ext)"
    }

    /// Moves `source` into `folder` and returns where it ended up.
    @discardableResult
    public static func move(_ source: URL, into folder: URL) throws -> URL {
        var status = stat()
        guard lstat(source.path, &status) == 0 else {
            throw FileMoverError.sourceMissing(source.path)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileMoverError.destinationMissing(folder.path)
        }

        let sourcePath = canonicalPath(source.path)
        let folderPath = canonicalPath(folder.path)
        if (sourcePath as NSString).deletingLastPathComponent == folderPath {
            throw FileMoverError.alreadyInDestination(source.path)
        }
        if folderPath == sourcePath || folderPath.hasPrefix(sourcePath + "/") {
            throw FileMoverError.destinationInsideSource(source.path)
        }

        let name = source.lastPathComponent
        for attempt in 1...maximumAttempts {
            let target = folder.appendingPathComponent(candidateName(for: name, attempt: attempt))
            if try moveExclusively(source, to: target) {
                return target
            }
        }
        throw FileMoverError.noFreeName(source.path)
    }

    /// Returns `false` if `target` already exists, so the caller tries the next name.
    private static func moveExclusively(_ source: URL, to target: URL) throws -> Bool {
        if renamex_np(source.path, target.path, UInt32(RENAME_EXCL)) == 0 {
            return true
        }
        switch errno {
        case EEXIST:
            return false
        case EXDEV:
            return try copyThenRemove(source, to: target)
        default:
            throw FileMoverError.moveFailed(String(cString: strerror(errno)))
        }
    }

    /// Moving to another volume: copy (which refuses to overwrite), check the
    /// copy is complete, and only then move the original to the Trash.
    /// Ordino never deletes permanently, not even the original of a finished copy.
    private static func copyThenRemove(_ source: URL, to target: URL) throws -> Bool {
        let manager = FileManager.default
        do {
            try manager.copyItem(at: source, to: target)
        } catch CocoaError.fileWriteFileExists {
            return false
        } catch {
            throw FileMoverError.moveFailed(error.localizedDescription)
        }
        guard FileSignature.read(source)?.size == FileSignature.read(target)?.size else {
            try? manager.trashItem(at: target, resultingItemURL: nil)
            throw FileMoverError.moveFailed("The copy on the other volume is incomplete.")
        }
        do {
            try manager.trashItem(at: source, resultingItemURL: nil)
        } catch {
            throw FileMoverError.moveFailed(error.localizedDescription)
        }
        return true
    }
}
