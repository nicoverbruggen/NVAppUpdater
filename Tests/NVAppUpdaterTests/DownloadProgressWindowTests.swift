import AppKit
import XCTest
@testable import NVAppUpdater

@MainActor
final class DownloadProgressWindowTests: XCTestCase {
    override func tearDown() async throws {
        for window in NSApp.windows where window.identifier == DownloadProgressWindowController.windowIdentifier {
            window.close()
        }
        try await super.tearDown()
    }

    func testProgressWindowAppearsUpdatesAndCloses() async throws {
        let harness = DownloadProgressWindowHarness(image: nil)
        let totalBytes = Int64(100 * 1024 * 1024)
        let updateCount = 6
        let updateInterval: UInt64 = 500_000_000
        let startedAt = Date()

        harness.showWindow()
        XCTAssertTrue(harness.hasVisibleWindow)
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.title.isEmpty })

        for update in 1...updateCount {
            try await Task.sleep(nanoseconds: updateInterval)
            let written = totalBytes * Int64(update) / Int64(updateCount)
            harness.update(written: written, total: totalBytes)
            XCTAssertTrue(harness.hasVisibleWindow)
        }

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startedAt), 3)

        harness.finish()
        XCTAssertFalse(harness.hasVisibleWindow)
    }

    func testProgressWindowWaitsForScheduledDelayBeforeAppearing() async throws {
        let harness = DownloadProgressWindowHarness()

        harness.showWindow(after: 3)
        XCTAssertFalse(harness.hasVisibleWindow)

        try await Task.sleep(nanoseconds: 2_000_000_000)
        harness.runMainLoop()
        XCTAssertFalse(harness.hasVisibleWindow)

        try await Task.sleep(nanoseconds: 1_250_000_000)
        harness.runMainLoop()
        XCTAssertTrue(harness.hasVisibleWindow)

        harness.finish()
    }

    func testProgressWindowNeverAppearsWhenFinishedBeforeScheduledDelay() async throws {
        let harness = DownloadProgressWindowHarness()

        harness.showWindow(after: 3)
        XCTAssertFalse(harness.hasVisibleWindow)

        try await Task.sleep(nanoseconds: 1_000_000_000)
        harness.finish()
        XCTAssertFalse(harness.hasVisibleWindow)

        try await Task.sleep(nanoseconds: 2_500_000_000)
        harness.runMainLoop()
        XCTAssertFalse(harness.hasVisibleWindow)
    }
}

@MainActor
private final class DownloadProgressWindowHarness {
    static let appName = "NVAppUpdater Window Harness"

    private let controller: DownloadProgressWindowController

    var hasVisibleWindow: Bool {
        !visibleWindows.isEmpty
    }

    var visibleWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.identifier == DownloadProgressWindowController.windowIdentifier && window.isVisible
        }
    }

    init(image: NSImage? = nil) {
        _ = NSApplication.shared
        self.controller = DownloadProgressWindowController(appName: Self.appName, image: image)
    }

    func showWindow(after delay: TimeInterval = 0) {
        controller.scheduleAppearance(after: delay)
        runMainLoop()
    }

    func update(written: Int64, total: Int64) {
        controller.update(written: written, total: total)
        runMainLoop()
    }

    func finish() {
        controller.finish()
        runMainLoop()
    }

    func runMainLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
}
