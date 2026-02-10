import Foundation
import os

/// Monitors directories for filesystem changes and notifies via callback.
///
/// Uses `DispatchSource.makeFileSystemObjectSource` with `O_EVTONLY` file descriptors
/// to watch directories. Events are debounced to coalesce rapid changes.
actor FileWatcher {
    private let logger = Logger(subsystem: "com.claudeshelf.app", category: "FileWatcher")
    private var sources: [String: (source: DispatchSourceFileSystemObject, fd: Int32)] = [:]
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval
    private var onChange: (@Sendable () async -> Void)?

    init(debounceInterval: TimeInterval = 1.0) {
        self.debounceInterval = debounceInterval
    }

    /// Starts watching the given directories for changes.
    func start(directories: [String], onChange: @escaping @Sendable () async -> Void) {
        self.onChange = onChange
        stopAll()

        for dir in directories {
            guard FileManager.default.fileExists(atPath: dir) else {
                logger.debug("Skipping non-existent directory for watching")
                continue
            }

            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else {
                logger.warning("Failed to open directory for watching")
                continue
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .attrib],
                queue: DispatchQueue.global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                guard let self else { return }
                Task {
                    await self.handleEvent()
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            sources[dir] = (source: source, fd: fd)
        }

        logger.info("File watcher started for \(directories.count) directories")
    }

    /// Stops watching all directories.
    func stop() {
        stopAll()
        onChange = nil
        logger.info("File watcher stopped")
    }

    private func stopAll() {
        debounceTask?.cancel()
        debounceTask = nil
        for (_, entry) in sources {
            entry.source.cancel()
        }
        sources.removeAll()
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
        logger.info("File changes detected, triggering refresh")
        await onChange()
    }

    deinit {
        for (_, entry) in sources {
            entry.source.cancel()
        }
    }
}
