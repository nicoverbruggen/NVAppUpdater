//
//  Created by Nico Verbruggen on 30/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa
import NVAlert

open class UpdateCheck
{
    let caskUrl: URL
    let selfUpdaterName: String
    let selfUpdaterPath: String

    private var releaseNotesUrlCallback: ((NVCaskFile) -> URL?)? = nil
    private var caskFile: NVCaskFile!
    private var newerVersion: AppVersion!

    /**
     * Create a new update check instance. Once created, you should call `perform` on this instance.
     *
     * - Parameter selfUpdaterName: The name of the self-updater .app file. For example, "App Self-Updater.app".
     *   This binary should exist as a resource of the current application.
     *
     * - Parameter selfUpdaterPath: The directory that is used by the self-updater.
     *   A small manifest named `update.json` will be placed in this directory and this
     *   should be correspond to the `selfUpdaterPath` in `SelfUpdater`.
     *
     * - Parameter caskUrl: The URL where the Cask file is expected to be located. Redirects will
     *   be followed when retrieving and validating the Cask file.
     */
    public init(
        selfUpdaterName: String,
        selfUpdaterPath: String,
        caskUrl: URL
    ) {
        self.selfUpdaterName = selfUpdaterName
        self.selfUpdaterPath = selfUpdaterPath
        self.caskUrl = caskUrl
    }

    public func resolvingReleaseNotes(with callback: @escaping (NVCaskFile) -> URL?) -> Self {
        self.releaseNotesUrlCallback = callback
        return self
    }

    /**
     * Perform the check for a new version.
     *
     * - Parameter promptOnFailure: Whether user interaction is required when failing to check
     *   or no new update is found. A user usually expects a prompt if they manually searched
     *   for updates.
     */
    public func perform(promptOnFailure: Bool = true) async {
        guard let caskFile = NVCaskFile.from(url: caskUrl) else {
            Log.text("The contents of the CaskFile at '\(caskUrl.absoluteString)' could not be retrieved.")
            return await presentCouldNotRetrieveUpdate(promptOnFailure)
        }

        self.caskFile = caskFile

        let currentVersion = AppVersion.fromCurrentVersion()

        guard let onlineVersion = AppVersion.from(caskFile.version) else {
            Log.text("The version string from the CaskFile could not be read.")
            return await presentCouldNotRetrieveUpdate(promptOnFailure)
        }

        self.newerVersion = onlineVersion

        Log.text("The latest version read from '\(caskUrl.lastPathComponent)' is: v\(onlineVersion.computerReadable).")
        Log.text("The current version is v\(currentVersion.computerReadable).")

        if onlineVersion > currentVersion {
            await presentNewerVersionAvailable()
        } else if promptOnFailure {
            await presentVersionIsUpToDate(promptOnFailure)
        }
    }

    // MARK: - Alerts

    private func presentCouldNotRetrieveUpdate(_ promptOnFailure: Bool) async {
        Log.text("Could not retrieve update manifest!")

        if promptOnFailure {
            await Alert.confirm(
                title: "Could not retrieve update information!",
                description: "There was an issue retrieving information about possible updates. This could be a connection or server issue. Check your internet connection and try again later."
            )
        }
    }

    private func presentVersionIsUpToDate(_ promptOnFailure: Bool) async {
        Log.text("Version is up-to-date!")

        if promptOnFailure {
            await Alert.confirm(
                title: "The app is up-to-date!",
                description: "The version on the server is not newer than this version, so you're all good."
            )
        }
    }

    private func presentNewerVersionAvailable() async {
        Log.text("A newer version is available!")

        let current = AppVersion.fromCurrentVersion()

        let alert = await NVAlert().withInformation(
            title: "An updated version of \(Executable.name) is available.",
            subtitle: "Version \(newerVersion.version) is available for download.",
            description: "Do you want to download and install this updated version?"
        )
        .withPrimary(
            text: "Install",
            action: { vc in
                vc.close(with: .OK)
                self.launchSelfUpdater()
            }
        )
        .withTertiary(text: "Dismiss", action: { vc in
            vc.close(with: .OK)
        })

        if let callback = self.releaseNotesUrlCallback,
           let url = callback(self.caskFile) {
            await alert.withSecondary(text: "View Release Notes") { _ in
                NSWorkspace.shared.open(url)
            }
        }

        await alert.show()
    }

    // MARK: - Functional

    private func launchSelfUpdater() {
        let updater = Bundle.main.resourceURL!.path + "/\(selfUpdaterName)"

        system_quiet("mkdir -p \(selfUpdaterPath) 2> /dev/null")

        let updaterDirectory = selfUpdaterPath
            .replacingOccurrences(of: "~", with: NSHomeDirectory())

        system_quiet("cp -R \"\(updater)\" \"\(updaterDirectory)/\(selfUpdaterName)\"")

        try! "{ \"url\": \"\(caskFile.url)\", \"sha256\": \"\(caskFile.sha256)\" }".write(
            to: URL(fileURLWithPath: "\(updaterDirectory)/update.json"),
            atomically: true,
            encoding: .utf8
        )

        NSWorkspace.shared.openApplication(
            at: NSURL(fileURLWithPath: updater, isDirectory: true) as URL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in
            Log.text("The updater has been launched successfully!")
        }
    }
}
