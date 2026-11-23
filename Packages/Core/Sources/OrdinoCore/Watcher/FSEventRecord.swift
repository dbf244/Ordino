import CoreServices
import Foundation

/// The FSEvents flags Ordino cares about.
public struct FSEventFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    private init(_ flag: Int) {
        self.rawValue = UInt32(flag)
    }

    public static let mustScanSubDirs = FSEventFlags(kFSEventStreamEventFlagMustScanSubDirs)
    public static let userDropped = FSEventFlags(kFSEventStreamEventFlagUserDropped)
    public static let kernelDropped = FSEventFlags(kFSEventStreamEventFlagKernelDropped)
    public static let rootChanged = FSEventFlags(kFSEventStreamEventFlagRootChanged)
    public static let itemCreated = FSEventFlags(kFSEventStreamEventFlagItemCreated)
    public static let itemRemoved = FSEventFlags(kFSEventStreamEventFlagItemRemoved)
    public static let itemInodeMetaMod = FSEventFlags(kFSEventStreamEventFlagItemInodeMetaMod)
    public static let itemRenamed = FSEventFlags(kFSEventStreamEventFlagItemRenamed)
    public static let itemModified = FSEventFlags(kFSEventStreamEventFlagItemModified)
    public static let itemXattrMod = FSEventFlags(kFSEventStreamEventFlagItemXattrMod)
    public static let itemIsFile = FSEventFlags(kFSEventStreamEventFlagItemIsFile)
    public static let itemIsDir = FSEventFlags(kFSEventStreamEventFlagItemIsDir)
    public static let itemIsSymlink = FSEventFlags(kFSEventStreamEventFlagItemIsSymlink)
}

/// One raw event as FSEvents delivered it.
public struct FSEventRecord: Sendable, Equatable {
    /// Canonical path (symlinks resolved, e.g. `/private/var/...`).
    public let path: String
    public let flags: FSEventFlags
    /// The file's inode number; pairs the two halves of a rename.
    public let fileID: UInt64?
    public let eventID: UInt64

    public init(path: String, flags: FSEventFlags, fileID: UInt64?, eventID: UInt64) {
        self.path = path
        self.flags = flags
        self.fileID = fileID
        self.eventID = eventID
    }
}
