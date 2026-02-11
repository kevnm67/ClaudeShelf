import CoreServices
import Foundation
import os

/// Bridging helper to pass context from C callback into actor-isolated code.
/// Must be a class (not actor) because `Unmanaged` requires a reference type,
/// and the FSEvents C callback cannot capture Swift closures directly.
private final class FileWatcherContext: @unchecked Sendable {
    let onEvent: @Sendable () -> Void
    init(onEvent: @escaping @Sendable () -> Void) { self.onEvent = onEvent }
    func notify() { onEvent() }
}

/// Monitors directories for filesystem changes and notifies via callback.
///
/// Uses FSEvents with `kFSEventStreamCreateFlagFileEvents` for recursive
/// subdirectory monitoring. Events are debounced to coalesce rapid changes.
actor FileWatcher {
    private static let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileWatcher")
    private var streamRef: FSEventStreamRef?
    private var callbackContext: FileWatcherContext?
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval
    private var onChange: (@Sendable () async -> Void)?

    init(debounceInterval: TimeInterval = 1.0) {
        self.debounceInterval = debounceInterval
    }

    /// C callback for FSEvents — dispatches to the actor via the context pointer.
    private static let eventCallback: FSEventStreamCallback = {
        (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
        guard let info = clientCallBackInfo else { return }
        let context = Unmanaged<FileWatcherContext>.fromOpaque(info).takeUnretainedValue()
        context.notify()
    }

    /// Starts watching the given directories for changes.
    func start(directories: [String], onChange: @escaping @Sendable () async -> Void) {
        self.onChange = onChange
        stopStream()

        let existingDirs = directories.filter { FileManager.default.fileExists(atPath: $0) }

        guard !existingDirs.isEmpty else {
            Self.logger.debug("No existing directories to watch")
            return
        }

        let context = FileWatcherContext { [weak self] in
            guard let self else { return }
            Task {
                await self.handleEvent()
            }
        }
        self.callbackContext = context

        var streamContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(context).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = existingDirs as CFArray

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.eventCallback,
            &streamContext,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes
                    | kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagNoDefer
            )
        ) else {
            Self.logger.warning("Failed to create FSEventStream")
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
        self.streamRef = stream

        Self.logger.info("File watcher started for \(directories.count) directories")
    }

    /// Stops watching all directories.
    func stop() {
        stopStream()
        onChange = nil
        Self.logger.info("File watcher stopped")
    }

    private func stopStream() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        streamRef = nil
        callbackContext = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    private func handleEvent() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self, debounceInterval] in
            do {
                try await Task.sleep(for: .seconds(debounceInterval))
                guard !Task.isCancelled else { return }
                await self?.fireCallback()
            } catch {
                // Task cancelled — new event came in, debounce restarted
            }
        }
    }

    private func fireCallback() async {
        guard let onChange else { return }
        Self.logger.info("File changes detected, triggering refresh")
        await onChange()
    }

}
