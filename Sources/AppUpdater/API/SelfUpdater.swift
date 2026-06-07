//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Cocoa

open class SelfUpdater: NSObject, NSApplicationDelegate {

    public enum ProgressWindowDisplayMode {
        case always
        case whenUpdatingTakesLongerThan(TimeInterval)
    }

    enum ProgressStep: Int, CaseIterable {
        case downloadingUpdate
        case extractingUpdate
        case restartingApplication
    }

    // MARK: - Requires Configuration

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

    // MARK: - Regular Updater Flow

    // Set by the user
    private var appName: String
    private var bundleIdentifiers: [String]
    private var selfUpdaterPath: String
    private var downloadProgressImage: NSImage?

    public var progressWindowDisplayMode: ProgressWindowDisplayMode

    /// The hard wall-clock timeout applied when `downloadHardTimeout` is nil.
    public static let defaultDownloadHardTimeout: TimeInterval = 15 * 60

    /// The default delay before the progress window appears for longer downloads.
    public static let defaultProgressWindowDelay: TimeInterval = 3

    /// Optional hard wall-clock timeout (in seconds) for the update download. If
    /// the whole transfer takes longer than this, it is considered failed. When
    /// nil, the 15-minute default (`defaultDownloadHardTimeout`) is applied.
    public var downloadHardTimeout: TimeInterval? = nil

    // Determined during the flow of the updater
    private var updaterPath: String = ""
    private var manifestPath: String = ""

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

    func installUpdate() async {
        Log.text("===========================================")
        Log.text("\(Executable.name), version \(Executable.fullVersion)")
        Log.text("Using AppUpdater by Nico Verbruggen")
        Log.text("===========================================")

        Log.text("Configured for \(self.appName) bundles: \(self.bundleIdentifiers)")

        self.updaterPath = self.selfUpdaterPath
            .replacingOccurrences(of: "~", with: NSHomeDirectory())

        Log.text("Updater directory set to: \(self.updaterPath)")

        self.manifestPath = "\(updaterPath)/update.json"

        // Fetch the manifest on the local filesystem
        guard let manifest = await parseManifest() else { return }

        guard let downloadURL = await downloadURL(from: manifest) else { return }

        let progressWindow = await makeProgressWindow()
        await show(progressWindow)

        // Download the latest file
        let zipPath = await download(
            manifest,
            from: downloadURL,
            progressWindow: progressWindow
        )
        guard !zipPath.isEmpty else { return }

        // Extract and validate the downloaded app before touching the running app.
        await progressWindow.advance(toStepAt: ProgressStep.extractingUpdate.rawValue)
        let extractedAppPath = await extractAndValidate(zipPath: zipPath, progressWindow: progressWindow)
        guard !extractedAppPath.isEmpty else { return }

        // Once the update is ready, terminate the app and replace it.
        await progressWindow.advance(toStepAt: ProgressStep.restartingApplication.rawValue)
        await LaunchControl.terminateApplications(bundleIds: self.bundleIdentifiers)
        let appPath = await installExtractedApp(at: extractedAppPath, zipPath: zipPath)

        // Restart app, this will also close the updater
        _ = await LaunchControl.startApplication(at: appPath)

        await progressWindow.finish()
        exit(1)
    }

    private func parseManifest() async -> ReleaseManifest? {
        // Read out the correct information from the manifest JSON
        Log.text("Checking manifest file at \(manifestPath)...")

        do {
            let manifestText = try String(contentsOfFile: manifestPath)
            return try JSONDecoder().decode(ReleaseManifest.self, from: Data(manifestText.utf8))
        } catch {
            Log.text("Parsing the manifest failed (or the manifest file doesn't exist)!")
            await Alert.upgradeFailure(description: "The manifest file for a potential update was not found. Please try searching for updates again in \(appName).")
        }

        return nil
    }

    private func downloadURL(from manifest: ReleaseManifest) async -> URL? {
        // Ensure the manifest is valid
        guard let url = URL(string: manifest.url), url.scheme != nil else {
            Log.text("The manifest URL is invalid: \(manifest.url)")
            await Alert.upgradeFailure(description: Translations.invalidManifestURLDescription
                .replacingOccurrences(of: "%@", with: appName))
            return nil
        }

        // Ensure URL has a filename
        guard !url.lastPathComponent.isEmpty else {
            Log.text("The manifest URL does not point to a downloadable file: \(manifest.url)")
            await Alert.upgradeFailure(description: Translations.invalidManifestURLDescription
                .replacingOccurrences(of: "%@", with: appName))
            return nil
        }

        return url
    }

    private func download(
        _ manifest: ReleaseManifest,
        from url: URL,
        progressWindow: ProgressWindowController
    ) async -> String {
        // Remove all zips
        system_quiet("rm -rf \(updaterPath)/*.zip")

        // Get the destination URL
        let destination = URL(fileURLWithPath: "\(updaterPath)/\(url.lastPathComponent)")

        let downloader = FileDownloader { written, total in
            Task { @MainActor in
                progressWindow.update(written: written, total: total)
            }
        }

        // Failure scenario #1: the download itself failed (network, timeout, HTTP error).
        // This is distinct from a completed download that fails checksum validation below.
        do {
            try await downloader.download(from: url, to: destination, hardTimeout: downloadHardTimeout ?? Self.defaultDownloadHardTimeout)
        } catch {
            await progressWindow.finish()
            Log.text("The update could not be downloaded: \(error.localizedDescription)")
            await Alert.upgradeFailure(description: "The update could not be downloaded.\n\n\(error.localizedDescription)\n\nPlease check your internet connection and try again.")
            return ""
        }

        // Calculate the checksum for the downloaded file
        let checksum = system("openssl dgst -sha256 \"\(destination.path)\" | awk '{print $NF}'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !checksum.isEmpty else {
            Log.text("The update checksum could not be calculated.")
            await progressWindow.finish()
            await Alert.upgradeFailure(description: "The downloaded update could not be validated. Please try again.")
            return ""
        }

        // Compare the checksums
        Log.text("""
        Comparing checksums...
        Expected SHA256: \(manifest.sha256)
        Actual SHA256: \(checksum)
        """)

        // Failure scenario #2: downloaded fine, but the checksum doesn't match.
        if checksum != manifest.sha256 {
            Log.text("The checksums failed to match. Cancelling!")
            await progressWindow.finish()
            await Alert.upgradeFailure(description: "The downloaded update failed checksum validation. Please try again. If this issue persists, there may be an issue with the server and I do not recommend upgrading.")
            return ""
        }

        // Return the path to the zip
        return destination.path
    }

    @MainActor
    private func makeProgressWindow() -> ProgressWindowController {
        ProgressWindowController(
            title: Self.formatted(Translations.progressWindowTitle, appName: appName),
            stepTitles: Self.progressStepTitles(appName: appName),
            waitingForSizeText: Translations.downloadProgressWaitingForSize,
            byteProgressStepIndex: ProgressStep.downloadingUpdate.rawValue,
            image: downloadProgressImage
        )
    }

    static func progressStepTitles(appName: String) -> [String] {
        [
            Translations.progressStepDownloadingUpdate,
            Translations.progressStepExtractingUpdate,
            formatted(Translations.progressStepRestartingApp, appName: appName)
        ]
    }

    private static func formatted(_ string: String, appName: String) -> String {
        string.replacingOccurrences(of: "%@", with: appName)
    }

    private func show(_ progressWindow: ProgressWindowController) async {
        switch progressWindowDisplayMode {
        case .always:
            await progressWindow.show()
        case .whenUpdatingTakesLongerThan(let delay):
            await progressWindow.scheduleAppearance(after: delay)
        }
    }

    private func extractAndValidate(
        zipPath: String,
        progressWindow: ProgressWindowController
    ) async -> String {
        // Remove the directory that will contain the extracted update
        system_quiet("rm -rf \"\(updaterPath)/extracted\"")

        // Recreate the directory where we will unzip the .app file
        system_quiet("mkdir -p \"\(updaterPath)/extracted\"")

        // Make sure the updater directory exists
        var isDirectory: ObjCBool = true
        if !FileManager.default.fileExists(atPath: "\(updaterPath)/extracted", isDirectory: &isDirectory)
            || !isDirectory.boolValue {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: "The updater directory is missing. The automatic updater will quit. Make sure that `\(selfUpdaterPath)` is writeable.")
            return ""
        }

        // Unzip the file
        system_quiet("unzip \"\(zipPath)\" -d \"\(updaterPath)/extracted\"")

        // Find the .app file
        guard let appURL = extractedAppURL() else {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: "The downloaded file could not be extracted. The automatic updater will quit. Make sure that `\(selfUpdaterPath)` is writeable.")
            return ""
        }

        Log.text("Finished extracting: \(appURL.path)")

        // Make sure the file was extracted
        guard isValidApplication(at: appURL) else {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: "The downloaded file could not be extracted. The automatic updater will quit. Make sure that `\(selfUpdaterPath)` is writeable.")
            return ""
        }

        return appURL.path
    }

    private func installExtractedApp(at extractedAppPath: String, zipPath: String) async -> String {
        let app = URL(fileURLWithPath: extractedAppPath).lastPathComponent

        // Remove the original app
        Log.text("Removing \(app) before replacing...")
        system_quiet("rm -rf \"/Applications/\(app)\"")

        // Move the new app in place
        system_quiet("mv \"\(extractedAppPath)\" \"/Applications/\(app)\"")

        // Remove the zip
        system_quiet("rm \"\(zipPath)\"")

        // Remove the manifest
        system_quiet("rm \"\(manifestPath)\"")

        // Write a file that is only written when we upgraded successfully
        system_quiet("touch \"\(updaterPath)/upgrade.success\"")

        // Return the new location of the app
        return "/Applications/\(app)"
    }

    private func extractedAppURL() -> URL? {
        let extractedURL = URL(fileURLWithPath: "\(updaterPath)/extracted", isDirectory: true)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: extractedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents.first { url in
            guard url.pathExtension == "app",
                  let values = try? url.resourceValues(forKeys: [.isDirectoryKey]) else {
                return false
            }

            return values.isDirectory == true
        }
    }

    private func isValidApplication(at appURL: URL) -> Bool {
        guard let bundle = Bundle(url: appURL),
              let executable = bundle.infoDictionary?["CFBundleExecutable"] as? String,
              !executable.isEmpty else {
            return false
        }

        return FileManager.default.fileExists(
            atPath: appURL.appendingPathComponent("Contents/MacOS/\(executable)").path
        )
    }
}
