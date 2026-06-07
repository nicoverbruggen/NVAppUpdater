//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Cocoa

open class SelfUpdater: NSObject, NSApplicationDelegate {

    // MARK: - Types

    public enum ProgressWindowDisplayMode {
        /**
         * Show the progress window as soon as the update starts.
         */
        case always

        /**
         * Delay the progress window and only show it if the update is still running.
         *
         * This is useful when quick updates should complete silently, while slower
         * updates still give the user visible feedback.
         */
        case whenUpdatingTakesLongerThan(TimeInterval)
    }

    // MARK: - Defaults

    /**
     * The hard wall-clock timeout applied when `downloadHardTimeout` is nil.
     */
    public static let defaultDownloadHardTimeout: TimeInterval = 15 * 60

    /**
     * The default delay before the progress window appears for longer downloads.
     */
    public static let defaultProgressWindowDelay: TimeInterval = 3

    // MARK: - Configuration

    var appName: String
    var bundleIdentifiers: [String]
    var selfUpdaterPath: String
    var downloadProgressImage: NSImage?

    public var progressWindowDisplayMode: ProgressWindowDisplayMode

    /**
     * Optional hard wall-clock timeout (in seconds) for the update download. If
     * the whole transfer takes longer than this, it is considered failed. When
     * nil, the 15-minute default (`defaultDownloadHardTimeout`) is applied.
     */
    public var downloadHardTimeout: TimeInterval? = nil

    /**
     * Creates a self-updater delegate for the helper app that performs the update.
     *
     * The self-updater is expected to run as a separate `.app` bundle embedded in
     * the main application. `UpdateCheck` writes an `update.json` manifest into
     * `selfUpdaterPath`, launches this helper app, and this delegate then downloads,
     * validates, extracts, installs, and relaunches the updated app.
     *
     * - Parameters:
     *   - appName: The display name of the app being updated. This is used in alerts
     *     and progress-window text.
     *
     *   - bundleIdentifiers: One or more bundle identifiers for running instances of
     *     the app being updated. These are terminated only after the downloaded update
     *     has been extracted and validated.
     *
     *   - selfUpdaterPath: A writable directory shared between `UpdateCheck` and the
     *     helper updater app. `~` is expanded to the current user's home directory.
     *
     *   - downloadProgressImage: An optional image to show in the progress window.
     *     If not set, defaults to the icon of the updater app.
     *
     *   - progressWindowDisplayMode: Controls whether the progress window is shown
     *     immediately or only after the update has taken longer than a configured delay.
     */
    public init(
        appName: String,
        bundleIdentifiers: [String],
        selfUpdaterPath: String,
        downloadProgressImage: NSImage? = nil,
        progressWindowDisplayMode: ProgressWindowDisplayMode = .whenUpdatingTakesLongerThan(SelfUpdater.defaultProgressWindowDelay)
    ) {
        self.appName = appName
        self.bundleIdentifiers = bundleIdentifiers
        self.selfUpdaterPath = selfUpdaterPath
        self.downloadProgressImage = downloadProgressImage
        self.progressWindowDisplayMode = progressWindowDisplayMode
    }

    // MARK: - Runtime State

    var updaterPath: String = ""
    var manifestPath: String = ""

    // MARK: - NSApplicationDelegate

    public func applicationDidFinishLaunching(_ aNotification: Notification) {
        Alert.appName = self.appName
        Task { await self.installUpdate() }
    }

    public func applicationWillTerminate(_ aNotification: Notification) {
        exit(1)
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }

    // MARK: - Update Flow

    func installUpdate() async {
        Log.text("===========================================")
        Log.text("\(Executable.name), version \(Executable.fullVersion)")
        Log.text("Using AppUpdater by Nico Verbruggen")
        Log.text("===========================================")

        Log.text("Configured for \(self.appName) bundles: \(self.bundleIdentifiers)")

        self.updaterPath = self.selfUpdaterPath
            .replacingOccurrences(of: "~", with: NSHomeDirectory())

        Log.text("Updater directory set to: \(self.updaterPath)")

        // Load the path for the location of the manifest
        self.manifestPath = "\(updaterPath)/update.json"

        // Update check should have written this manifest
        guard let manifest = await parseManifest() else { return }

        // Parse and validate the download URL
        guard let downloadURL = await validateDownloadUrl(from: manifest) else { return }

        // Show the progress window, if relevant
        let progressWindow = await makeProgressWindow()
        await show(progressWindow)

        // Download the latest file
        let zipPath = await download(manifest, from: downloadURL, progressWindow: progressWindow)
        guard !zipPath.isEmpty else { return }

        // Extract and validate the downloaded app before touching the running app
        await progressWindow.advance(toStepAt: ProgressStep.extractingUpdate.rawValue)
        let extractedAppPath = await extractAndValidate(zipPath: zipPath, progressWindow: progressWindow)
        guard !extractedAppPath.isEmpty else { return }

        // Once the update is ready, terminate the app and replace it
        await progressWindow.advance(toStepAt: ProgressStep.restartingApplication.rawValue)
        let didTerminate = await LaunchControl.terminateApplications(bundleIds: self.bundleIdentifiers)
        guard didTerminate else {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: Translations.terminationFailedDescription
                .replacingOccurrences(of: "%@", with: appName))
            return
        }

        let appPath = await installExtractedApp(at: extractedAppPath, zipPath: zipPath)

        // Restarting the app completes the visible flow; the helper updater then exits
        _ = await LaunchControl.startApplication(at: appPath)

        // Terminate the self-updater!
        await progressWindow.finish()
        exit(1)
    }
}
