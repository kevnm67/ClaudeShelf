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
        let watcher = FileWatcher(debounceInterval: 0.3)

        await watcher.start(directories: [tempDir.path]) {
            await counter.increment()
            expectation.fulfill()
        }

        // Rapid file creation — should coalesce into 1 callback
        for i in 0..<5 {
            let path = tempDir.appendingPathComponent("file\(i).txt").path
            try? "data".write(toFile: path, atomically: true, encoding: .utf8)
            try? await Task.sleep(for: .milliseconds(50))
        }

        await fulfillment(of: [expectation], timeout: 3.0)
        // Give a bit more time to see if extra callbacks fire
        try? await Task.sleep(for: .milliseconds(500))
        let callCount = await counter.count
        XCTAssertEqual(callCount, 1, "Debounce should coalesce rapid events into 1 callback")
        await watcher.stop()
    }
}
