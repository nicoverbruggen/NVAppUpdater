import AppKit
import XCTest
@testable import NVAppUpdater

@MainActor
final class ProgressWindowTests: XCTestCase {
    override func tearDown() async throws {
        for window in NSApplication.shared.windows where window.identifier == ProgressWindowController.windowIdentifier {
            window.close()
        }
        try await super.tearDown()
    }

    func testKnownTotalReportsDeterminateFraction() {
        let progress = ProgressWindowState(stepTitles: [])
        progress.bytesWritten = 25
        progress.totalBytes = 100

        XCTAssertFalse(progress.isIndeterminate)
        XCTAssertEqual(progress.fractionCompleted, 0.25)
    }

    func testUnknownTotalIsIndeterminate() {
        let progress = ProgressWindowState(stepTitles: [])
        progress.bytesWritten = 25
        progress.totalBytes = NSURLSessionTransferSizeUnknown

        XCTAssertTrue(progress.isIndeterminate)
        XCTAssertEqual(progress.fractionCompleted, 0)
    }

    func testSelfUpdaterDefaultsToDelayedProgressWindow() {
        let updater = SelfUpdater(
            appName: "NVAppUpdater Window Harness",
            bundleIdentifiers: ["com.example.app"],
            selfUpdaterPath: "/tmp"
        )

        guard case .whenUpdatingTakesLongerThan(let delay) = updater.progressWindowDisplayMode else {
            return XCTFail("Expected the self-updater to show progress after a delay by default.")
        }

        XCTAssertEqual(delay, SelfUpdater.defaultProgressWindowDelay)
    }

    func testSelfUpdaterCanAlwaysShowProgressWindow() {
        let updater = SelfUpdater(
            appName: "NVAppUpdater Window Harness",
            bundleIdentifiers: ["com.example.app"],
            selfUpdaterPath: "/tmp",
            progressWindowDisplayMode: .always
        )

        guard case .always = updater.progressWindowDisplayMode else {
            return XCTFail("Expected the self-updater to always show progress.")
        }
    }

    func testProgressWindowAppearsUpdatesAndCloses() async throws {
        let harness = ProgressWindowHarness(image: nil)
        let totalBytes = Int64(100 * 1024 * 1024)
        let updateCount = 6
        let updateInterval: UInt64 = 500_000_000
        let startedAt = Date()

        harness.showWindow()
        XCTAssertTrue(harness.hasVisibleWindow)
        XCTAssertEqual(
            harness.contentTopOffset,
            ProgressWindowController.titlebarContentOffset
        )
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.title.isEmpty })
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.titleVisibility == .hidden })
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.titlebarAppearsTransparent })
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.toolbarStyle == .unified })
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.titlebarSeparatorStyle == .none })
        XCTAssertTrue(harness.visibleWindows.allSatisfy { $0.styleMask.contains(.fullSizeContentView) })

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

    func testProgressWindowMovesThroughSelfUpdaterFlow() async throws {
        let harness = ProgressWindowHarness()

        harness.showWindow()
        XCTAssertEqual(harness.stepTitles, [
            "Downloading update...",
            "Extracting update...",
            "Restarting Fake App..."
        ])
        XCTAssertEqual(harness.currentStepTitle, "Downloading update...")

        harness.update(written: 50 * 1024 * 1024, total: 100 * 1024 * 1024)
        XCTAssertEqual(harness.fractionCompleted, 0.5)

        harness.advance(to: .extractingUpdate)
        XCTAssertEqual(harness.currentStepTitle, "Extracting update...")

        harness.advance(to: .restartingApplication)
        XCTAssertEqual(harness.currentStepTitle, "Restarting Fake App...")

        harness.finish()
        XCTAssertFalse(harness.hasVisibleWindow)
    }

    func testProgressWindowKeepsStableHeightAcrossSteps() async throws {
        let harness = ProgressWindowHarness()

        harness.showWindow()
        harness.update(written: 50 * 1024 * 1024, total: 100 * 1024 * 1024)
        let downloadHeight = try XCTUnwrap(harness.windowHeight)

        harness.advance(to: .extractingUpdate)
        let extractionHeight = try XCTUnwrap(harness.windowHeight)
        XCTAssertEqual(extractionHeight, downloadHeight, accuracy: 1)

        harness.advance(to: .restartingApplication)
        let restartHeight = try XCTUnwrap(harness.windowHeight)
        XCTAssertEqual(restartHeight, downloadHeight, accuracy: 1)

        harness.finish()
    }

    func testProgressWindowWaitsForScheduledDelayBeforeAppearing() async throws {
        let harness = ProgressWindowHarness()

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
        let harness = ProgressWindowHarness()

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
private final class ProgressWindowHarness {
    static let appName = "Fake App"

    private let controller: ProgressWindowController

    var hasVisibleWindow: Bool {
        !visibleWindows.isEmpty
    }

    var visibleWindows: [NSWindow] {
        NSApp.windows.filter { window in
            window.identifier == ProgressWindowController.windowIdentifier && window.isVisible
        }
    }

    var stepTitles: [String] {
        controller.state.stepTitles
    }

    var currentStepTitle: String {
        controller.state.currentStepTitle
    }

    var fractionCompleted: Double {
        controller.state.fractionCompleted
    }

    var contentTopOffset: CGFloat {
        controller.contentTopOffset
    }

    var windowHeight: CGFloat? {
        visibleWindows.first?.frame.height
    }

    init(image: NSImage? = nil) {
        _ = NSApplication.shared
        self.controller = ProgressWindowController(
            title: SelfUpdater.Translations.progressWindowTitle
                .replacingOccurrences(of: "%@", with: Self.appName),
            stepTitles: SelfUpdater.progressStepTitles(appName: Self.appName),
            waitingForSizeText: SelfUpdater.Translations.downloadProgressWaitingForSize,
            byteProgressStepIndex: SelfUpdater.ProgressStep.downloadingUpdate.rawValue,
            image: image
        )
    }

    func showWindow(after delay: TimeInterval = 0) {
        controller.scheduleAppearance(after: delay)
        runMainLoop()
    }

    func update(written: Int64, total: Int64) {
        controller.update(written: written, total: total)
        runMainLoop()
    }

    func advance(to step: SelfUpdater.ProgressStep) {
        controller.advance(toStepAt: step.rawValue)
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
