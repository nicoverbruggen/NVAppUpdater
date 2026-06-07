//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Cocoa

open class SelfUpdater: NSObject, NSApplicationDelegate {

    // MARK: - Requires Configuration

    public init(appName: String, bundleIdentifiers: [String], selfUpdaterPath: String) {
        self.appName = appName
        self.bundleIdentifiers = bundleIdentifiers
        self.selfUpdaterPath = selfUpdaterPath
    }

    // MARK: - Regular Updater Flow

    // Set by the user
    private var appName: String
    private var bundleIdentifiers: [String]
    private var selfUpdaterPath: String

    /// The hard wall-clock timeout applied when `downloadHardTimeout` is nil.
    public static let defaultDownloadHardTimeout: TimeInterval = 15 * 60

    /// Optional hard wall-clock timeout (in seconds) for the update download. If
    /// the whole transfer takes longer than this, it is considered failed. When
    /// nil, the 15-minute default (`defaultDownloadHardTimeout`) is applied.
    public var downloadHardTimeout: TimeInterval? = nil

    // Determined during the flow of the updater
    private var updaterPath: String = ""
    private var manifestPath: String = ""
    private var manifest: ReleaseManifest! = nil

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
        let manifest = await parseManifest()!

        // Download the latest file
        let zipPath = await download(manifest)

        // Terminate all instances of app first
        await LaunchControl.terminateApplications(bundleIds: self.bundleIdentifiers)

        // Install the app based on the zip
        let appPath = await extractAndInstall(zipPath: zipPath)

        // Restart app, this will also close the updater
        _ = await LaunchControl.startApplication(at: appPath)

        exit(1)
    }

    private func parseManifest() async -> ReleaseManifest? {
        // Read out the correct information from the manifest JSON
        Log.text("Checking manifest file at \(manifestPath)...")

        do {
            let manifestText = try String(contentsOfFile: manifestPath)
            manifest = try JSONDecoder().decode(ReleaseManifest.self, from: manifestText.data(using: .utf8)!)
            return manifest
        } catch {
            Log.text("Parsing the manifest failed (or the manifest file doesn't exist)!")
            await Alert.upgradeFailure(description: "The manifest file for a potential update was not found. Please try searching for updates again in \(appName).")
        }

        return nil
    }

    private func download(_ manifest: ReleaseManifest) async -> String {
        // Remove all zips
        system_quiet("rm -rf \(updaterPath)/*.zip")

        guard let url = URL(string: manifest.url) else {
            Log.text("The manifest URL is invalid: \(manifest.url)")
            await Alert.upgradeFailure(description: "The update URL in the manifest is invalid. Please try searching for updates again in \(appName).")
            return ""
        }

        let destination = URL(fileURLWithPath: "\(updaterPath)/\(url.lastPathComponent)")

        // Show a progress window, but only if the download is still going after 3 seconds.
        let progressWindow = await DownloadProgressWindowController(appName: appName)
        await progressWindow.scheduleAppearance(after: 3)

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

        await progressWindow.finish()

        // Calculate the checksum for the downloaded file
        let checksum = system("openssl dgst -sha256 \"\(destination.path)\" | awk '{print $NF}'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Compare the checksums
        Log.text("""
        Comparing checksums...
        Expected SHA256: \(manifest.sha256)
        Actual SHA256: \(checksum)
        """)

        // Failure scenario #2: downloaded fine, but the checksum doesn't match.
        if checksum != manifest.sha256 {
            Log.text("The checksums failed to match. Cancelling!")
            await Alert.upgradeFailure(description: "The downloaded update failed checksum validation. Please try again. If this issue persists, there may be an issue with the server and I do not recommend upgrading.")
        }

        // Return the path to the zip
        return destination.path
    }

    private func extractAndInstall(zipPath: String) async -> String {
        // Remove the directory that will contain the extracted update
        system_quiet("rm -rf \"\(updaterPath)/extracted\"")

        // Recreate the directory where we will unzip the .app file
        system_quiet("mkdir -p \"\(updaterPath)/extracted\"")

        // Make sure the updater directory exists
        var isDirectory: ObjCBool = true
        if !FileManager.default.fileExists(atPath: "\(updaterPath)/extracted", isDirectory: &isDirectory) {
            await Alert.upgradeFailure(description: "The updater directory is missing. The automatic updater will quit. Make sure that `\(selfUpdaterPath)` is writeable.")
        }

        // Unzip the file
        system_quiet("unzip \"\(zipPath)\" -d \"\(updaterPath)/extracted\"")

        // Find the .app file
        let app = system("ls \"\(updaterPath)/extracted\" | grep .app")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        Log.text("Finished extracting: \(updaterPath)/extracted/\(app)")

        // Make sure the file was extracted
        if app.isEmpty {
            await Alert.upgradeFailure(description: "The downloaded file could not be extracted. The automatic updater will quit. Make sure that `\(selfUpdaterPath)` is writeable.")
        }

        // Remove the original app
        Log.text("Removing \(app) before replacing...")
        system_quiet("rm -rf \"/Applications/\(app)\"")

        // Move the new app in place
        system_quiet("mv \"\(updaterPath)/extracted/\(app)\" \"/Applications/\(app)\"")

        // Remove the zip
        system_quiet("rm \"\(zipPath)\"")

        // Remove the manifest
        system_quiet("rm \"\(manifestPath)\"")

        // Write a file that is only written when we upgraded successfully
        system_quiet("touch \"\(updaterPath)/upgrade.success\"")

        // Return the new location of the app
        return "/Applications/\(app)"
    }
}

struct ReleaseManifest: Codable {
    let url: String
    let sha256: String
}
