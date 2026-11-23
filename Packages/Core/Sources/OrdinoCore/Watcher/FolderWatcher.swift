import CoreServices
import Foundation

public enum FolderWatcherError: Error, Sendable, Equatable {
    case alreadyStarted
    case couldNotStart(String)
}

/// Streams raw FSEvents for one folder.
///
/// FSEvents is push-based: while nothing changes, the watcher does no work.
/// Events arrive in batches every `latency` and are delivered on a private
/// serial queue, then handed to Swift concurrency through an `AsyncStream`.
public actor FolderWatcher {
    public let folder: URL
    private let latency: Duration
    private var running: RunningStream?

    public init(folder: URL, latency: Duration = .milliseconds(200)) {
        self.folder = folder
        self.latency = latency
    }

    /// Starts watching. Each element is one batch of events, oldest first.
    public func start() throws -> AsyncStream<[FSEventRecord]> {
        guard running == nil else { throw FolderWatcherError.alreadyStarted }

        let (events, continuation) = AsyncStream.makeStream(of: [FSEventRecord].self)
        let sink = EventSink(continuation: continuation)

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(sink).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<EventSink>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info else { return }
                Unmanaged<EventSink>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagUseExtendedData
                | kFSEventStreamCreateFlagWatchRoot
        )

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, count, paths, flags, ids in
                guard let info else { return }
                let sink = Unmanaged<EventSink>.fromOpaque(info).takeUnretainedValue()
                sink.deliver(count: count, paths: paths, flags: flags, ids: ids)
            },
            &context,
            [folder.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            CFTimeInterval(latency.seconds),
            flags
        ) else {
            continuation.finish()
            throw FolderWatcherError.couldNotStart(folder.path)
        }

        FSEventStreamSetDispatchQueue(created, DispatchQueue(label: "io.github.dbf244.Ordino.FolderWatcher", qos: .utility))
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            continuation.finish()
            throw FolderWatcherError.couldNotStart(folder.path)
        }

        running = RunningStream(stream: created, sink: sink)
        return events
    }

    /// Stops watching and ends the stream. Safe to call more than once.
    public func stop() {
        running = nil
    }
}

/// Owns a started FSEvents stream and tears it down when released, so the
/// stream stops whether the watcher is stopped or simply deallocated.
private final class RunningStream {
    private let stream: FSEventStreamRef
    private let sink: EventSink

    init(stream: FSEventStreamRef, sink: EventSink) {
        self.stream = stream
        self.sink = sink
    }

    deinit {
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        sink.continuation.finish()
    }
}

/// Receives FSEvents callbacks on the watcher's queue and forwards them.
/// It only holds a `Sendable` continuation, so it is safe to share.
private final class EventSink: Sendable {
    let continuation: AsyncStream<[FSEventRecord]>.Continuation

    init(continuation: AsyncStream<[FSEventRecord]>.Continuation) {
        self.continuation = continuation
    }

    func deliver(
        count: Int,
        paths: UnsafeMutableRawPointer,
        flags: UnsafePointer<FSEventStreamEventFlags>,
        ids: UnsafePointer<FSEventStreamEventId>
    ) {
        // With kFSEventStreamCreateFlagUseExtendedData, `paths` is a CFArray of CFDictionary.
        let array = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as NSArray
        var records: [FSEventRecord] = []
        records.reserveCapacity(count)
        for index in 0..<min(count, array.count) {
            guard let info = array[index] as? NSDictionary,
                  let path = info[kFSEventStreamEventExtendedDataPathKey] as? String
            else { continue }
            let fileID = (info[kFSEventStreamEventExtendedFileIDKey] as? NSNumber)?.uint64Value
            records.append(FSEventRecord(
                path: path,
                flags: FSEventFlags(rawValue: flags[index]),
                fileID: fileID,
                eventID: ids[index]
            ))
        }
        if !records.isEmpty {
            continuation.yield(records)
        }
    }
}

extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
