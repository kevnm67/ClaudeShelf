import XCTest
@testable import ClaudeShelf

/// Thread-safe counter for use in concurrent test callbacks.
private actor CallCounter {
    var count = 0

    func increment() {
        count += 1
    }
}

final class FileWatcherTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testWatcherStartsAndStops() async {
        let watcher = FileWatcher(debounceInterval: 0.1)
        await watcher.start(directories: [tempDir.path]) { }
        await watcher.stop()
        // No crash = success
    }

    func testWatcherSkipsNonExistentDirectories() async {
        let watcher = FileWatcher(debounceInterval: 0.1)
        await watcher.start(directories: ["/nonexistent/path/\(UUID().uuidString)"]) { }
        await watcher.stop()
    }

    func testWatcherDetectsFileCreation() async {
        let expectation = XCTestExpectation(description: "Change detected")
        let watcher = FileWatcher(debounceInterval: 0.2)

        await watcher.start(directories: [tempDir.path]) {
            expectation.fulfill()
        }

        // Create a file to trigger the watcher
        let filePath = tempDir.appendingPathComponent("test.txt").path
        try? "hello".write(toFile: filePath, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 3.0)
        await watcher.stop()
    }

    func testDebounceCoalescesRapidEvents() async {
        let counter = CallCounter()
        let expectation = XCTestExpectation(description: "Debounced callback")
        // FSEvents with kFSEventStreamCreateFlagFileEvents fires per-file events;
        // use a longer debounce to ensure all rapid writes coalesce into one callback.
        let watcher = FileWatcher(debounceInterval: 0.8)

        await watcher.start(directories: [tempDir.path]) {
            await counter.increment()
            expectation.fulfill()
        }

        // Rapid file creation — should coalesce into 1 callback
        for i in 0..<5 {
            let path = tempDir.appendingPathComponent("file\(i).txt").path
            try? "data".write(toFile: path, atomically: true, encoding: .utf8)
            try? await Task.sleep(for: .milliseconds(30))
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        // Give a bit more time to see if extra callbacks fire
        try? await Task.sleep(for: .milliseconds(1000))
        let callCount = await counter.count
        XCTAssertEqual(callCount, 1, "Debounce should coalesce rapid events into 1 callback")
        await watcher.stop()
    }

    func testWatcherDetectsSubdirectoryFileCreation() async {
        let subDir = tempDir.appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        let expectation = XCTestExpectation(description: "Subdirectory change detected")
        let watcher = FileWatcher(debounceInterval: 0.2)

        await watcher.start(directories: [tempDir.path]) {
            expectation.fulfill()
        }

        // Small delay to let FSEvents start
        try? await Task.sleep(for: .milliseconds(200))

        // Create file in subdirectory — this would FAIL with old DispatchSource
        let filePath = subDir.appendingPathComponent("nested.txt").path
        try? "nested content".write(toFile: filePath, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 5.0)
        await watcher.stop()
    }
}
