//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa

/**
 * Minimal shape of an app process that can be controlled by the updater.
 *
 * `NSRunningApplication` is difficult to construct in tests, so `LaunchControl`
 * works against this small protocol internally. Production code still uses
 * `NSRunningApplication`; tests can provide small fakes that terminate, refuse to
 * terminate, or belong to unrelated bundle identifiers.
 */
protocol RunningApplication {
    var bundleIdentifier: String? { get }
    var isTerminated: Bool { get }

    func terminate() -> Bool
}

/**
 * Minimal workspace interface used by `LaunchControl`.
 *
 * This keeps the updater's production behavior tied to `NSWorkspace` while letting
 * unit tests validate the termination-wait policy without launching or killing
 * real macOS applications.
 */
protocol ApplicationWorkspace {
    associatedtype Application: RunningApplication

    var runningApplications: [Application] { get }

    func openApplication(at url: URL) async -> NSRunningApplication?
}

extension NSRunningApplication: RunningApplication {}

/**
 * Production bridge to AppKit's shared workspace.
 */
struct SystemApplicationWorkspace: ApplicationWorkspace {
    var runningApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
    }

    func openApplication(at url: URL) async -> NSRunningApplication? {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, error in
                continuation.resume(returning: application)
            }
        }
    }
}

class LaunchControl {
    static let defaultTerminationTimeout: TimeInterval = 10
    static let defaultTerminationPollInterval: TimeInterval = 0.2

    public static func smartRestart(priority: [String]) async {
        for appPath in priority {
            if FileManager.default.fileExists(atPath: appPath) {
                let app = await LaunchControl.startApplication(at: appPath)
                if app != nil {
                    return
                }
            }
        }
    }

    public static func terminateApplications(
        bundleIds: [String],
        timeout: TimeInterval = defaultTerminationTimeout,
        pollInterval: TimeInterval = defaultTerminationPollInterval
    ) async -> Bool {
        await terminateApplications(
            bundleIds: bundleIds,
            timeout: timeout,
            pollInterval: pollInterval,
            workspace: SystemApplicationWorkspace()
        )
    }

    public static func startApplication(at path: String) async -> NSRunningApplication? {
        await startApplication(at: path, workspace: SystemApplicationWorkspace())
    }

    static func terminateApplications<Workspace: ApplicationWorkspace>(
        bundleIds: [String],
        timeout: TimeInterval = defaultTerminationTimeout,
        pollInterval: TimeInterval = defaultTerminationPollInterval,
        workspace: Workspace
    ) async -> Bool {
        let runningApplications = runningApplications(matching: bundleIds, in: workspace)

        // `terminate()` only requests termination. The updater waits below before
        // replacing the app bundle, so a save prompt or stalled quit cannot lead to
        // replacing an app that is still running.
        for application in runningApplications {
            _ = application.terminate()
        }

        return await waitForTermination(
            bundleIds: bundleIds,
            timeout: timeout,
            pollInterval: pollInterval,
            workspace: workspace
        )
    }

    static func startApplication<Workspace: ApplicationWorkspace>(
        at path: String,
        workspace: Workspace
    ) async -> NSRunningApplication? {
        let url = NSURL(fileURLWithPath: path, isDirectory: true) as URL
        return await workspace.openApplication(at: url)
    }

    private static func waitForTermination<Workspace: ApplicationWorkspace>(
        bundleIds: [String],
        timeout: TimeInterval,
        pollInterval: TimeInterval,
        workspace: Workspace
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let sleepInterval = max(pollInterval, 0.05)

        while Date() < deadline {
            if runningApplications(matching: bundleIds, in: workspace).isEmpty {
                return true
            }

            try? await Task.sleep(nanoseconds: UInt64(sleepInterval * 1_000_000_000))
        }

        return runningApplications(matching: bundleIds, in: workspace).isEmpty
    }

    private static func runningApplications<Workspace: ApplicationWorkspace>(
        matching bundleIds: [String],
        in workspace: Workspace
    ) -> [Workspace.Application] {
        workspace.runningApplications.filter { application in
            guard let bundleIdentifier = application.bundleIdentifier else { return false }
            return bundleIds.contains(bundleIdentifier) && !application.isTerminated
        }
    }
}
