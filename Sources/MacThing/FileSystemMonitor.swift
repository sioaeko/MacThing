import CoreServices
import Foundation

struct FileSystemChange: Sendable {
    let path: String
    let flags: FSEventStreamEventFlags
    let eventID: UInt64

    var requiresFullScan: Bool {
        contains(kFSEventStreamEventFlagMustScanSubDirs) ||
            contains(kFSEventStreamEventFlagKernelDropped) ||
            contains(kFSEventStreamEventFlagUserDropped) ||
            contains(kFSEventStreamEventFlagRootChanged) ||
            contains(kFSEventStreamEventFlagEventIdsWrapped)
    }

    var shouldScanParent: Bool {
        contains(kFSEventStreamEventFlagItemRenamed) ||
            contains(kFSEventStreamEventFlagItemRemoved)
    }

    func merging(_ other: FileSystemChange) -> FileSystemChange {
        FileSystemChange(path: path, flags: flags | other.flags, eventID: max(eventID, other.eventID))
    }

    private func contains(_ flag: Int) -> Bool {
        flags & FSEventStreamEventFlags(flag) != 0
    }
}

final class FileSystemMonitor: @unchecked Sendable {
    typealias ChangeHandler = @Sendable ([FileSystemChange], UInt64?) -> Void

    private let rootURL: URL
    private let excludedPathPrefixes: [String]
    private let sinceEventID: UInt64?
    private let onChange: ChangeHandler
    private var stream: FSEventStreamRef?

    init(
        rootURL: URL,
        excludedPathPrefixes: [String] = [],
        sinceEventID: UInt64? = nil,
        onChange: @escaping ChangeHandler
    ) {
        self.rootURL = rootURL
        self.excludedPathPrefixes = excludedPathPrefixes
        self.sinceEventID = sinceEventID
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [rootURL.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagNoDefer
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.eventCallback,
            &context,
            pathsToWatch,
            sinceEventID.map { FSEventStreamEventId($0) } ?? FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.75,
            flags
        )

        guard let stream else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    static func currentEventID() -> UInt64 {
        UInt64(FSEventsGetCurrentEventId())
    }

    private func receive(changes: [FileSystemChange]) {
        let latestEventID = changes.map(\.eventID).max()
        let relevantChanges = changes.filter { change in
            !Self.isPathExcluded(change.path, by: excludedPathPrefixes)
        }

        guard !relevantChanges.isEmpty || latestEventID != nil else {
            return
        }

        onChange(relevantChanges, latestEventID)
    }

    private static func isPathExcluded(_ path: String, by prefixes: [String]) -> Bool {
        let resolvedPath = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        return prefixes.contains { prefix in
            path == prefix ||
                path.hasPrefix(prefix + "/") ||
                resolvedPath == prefix ||
                resolvedPath.hasPrefix(prefix + "/")
        }
    }

    private static let eventCallback: FSEventStreamCallback = { _, info, eventCount, eventPaths, eventFlags, eventIDs in
        guard let info else {
            return
        }

        let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(info).takeUnretainedValue()
        let pathsArray = unsafeBitCast(eventPaths, to: CFArray.self) as NSArray
        var changes: [FileSystemChange] = []
        changes.reserveCapacity(eventCount)

        for index in 0..<eventCount {
            guard let path = pathsArray[index] as? String else {
                continue
            }
            changes.append(
                FileSystemChange(
                    path: path,
                    flags: eventFlags[index],
                    eventID: UInt64(eventIDs[index])
                )
            )
        }

        monitor.receive(changes: changes)
    }
}
