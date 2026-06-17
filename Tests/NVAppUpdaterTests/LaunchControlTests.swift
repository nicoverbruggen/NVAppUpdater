import Cocoa
import XCTest
@testable import NVAppUpdater

final class LaunchControlTests: XCTestCase {
    func testTerminateApplicationsTerminatesMatchingApplications() async {
        let application = FakeRunningApplication(bundleIdentifier: "com.example.app")
        let workspace = FakeApplicationWorkspace(runningApplications: [application])

        let didTerminate = await LaunchControl.terminateApplications(
            bundleIds: ["com.example.app"],
            timeout: 0.1,
            pollInterval: 0.01,
            workspace: workspace
        )

        XCTAssertTrue(didTerminate)
        XCTAssertEqual(application.terminateCallCount, 1)
    }

    func testTerminateApplicationsIgnoresUnrelatedBundleIdentifiers() async {
        let application = FakeRunningApplication(bundleIdentifier: "com.example.other")
        let workspace = FakeApplicationWorkspace(runningApplications: [application])

        let didTerminate = await LaunchControl.terminateApplications(
            bundleIds: ["com.example.app"],
            timeout: 0.1,
            pollInterval: 0.01,
            workspace: workspace
        )

        XCTAssertTrue(didTerminate)
        XCTAssertEqual(application.terminateCallCount, 0)
    }

    func testTerminateApplicationsReturnsTrueWhenNoMatchingApplicationsAreRunning() async {
        let workspace = FakeApplicationWorkspace(runningApplications: [])

        let didTerminate = await LaunchControl.terminateApplications(
            bundleIds: ["com.example.app"],
            timeout: 0.1,
            pollInterval: 0.01,
            workspace: workspace
        )

        XCTAssertTrue(didTerminate)
    }

    func testTerminateApplicationsReturnsFalseWhenApplicationDoesNotQuitBeforeTimeout() async {
        let application = FakeRunningApplication(
            bundleIdentifier: "com.example.app",
            ignoresTermination: true
        )
        let workspace = FakeApplicationWorkspace(runningApplications: [application])

        let didTerminate = await LaunchControl.terminateApplications(
            bundleIds: ["com.example.app"],
            timeout: 0.05,
            pollInterval: 0.01,
            workspace: workspace
        )

        XCTAssertFalse(didTerminate)
        XCTAssertEqual(application.terminateCallCount, 1)
    }
}

private final class FakeApplicationWorkspace: ApplicationWorkspace {
    var runningApplications: [FakeRunningApplication]

    init(runningApplications: [FakeRunningApplication]) {
        self.runningApplications = runningApplications
    }

    func openApplication(at url: URL) async -> Bool {
        false
    }
}

private final class FakeRunningApplication: RunningApplication {
    let bundleIdentifier: String?
    private let ignoresTermination: Bool
    private(set) var terminateCallCount = 0
    private var terminated = false

    var isTerminated: Bool {
        terminated
    }

    init(
        bundleIdentifier: String?,
        ignoresTermination: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.ignoresTermination = ignoresTermination
    }

    func terminate() -> Bool {
        terminateCallCount += 1

        if !ignoresTermination {
            terminated = true
        }

        return !ignoresTermination
    }
}
