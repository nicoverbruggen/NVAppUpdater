//
//  Created by Nico Verbruggen on 30/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa
import NVAlert

open class UpdateCheck {
    let caskUrl: URL
    let selfUpdaterName: String
    let selfUpdaterPath: String
    let isInteractive: Bool

    private var releaseNotesUrlCallback: ((NVCaskFile) -> URL?)? = nil

    /**
     * Create a new update check instance. Once created, you should call `perform` on this instance.
     *
     * - Parameter selfUpdaterName: The name of the self-updater .app file. For example, "App Self-Updater.app".
     *   This binary should exist as a resource of the current application.
     *
     * - Parameter selfUpdaterPath: The directory that is used by the self-updater.
     *   A small manifest named `update.json` will be placed in this directory and this
     *   should correspond to the `selfUpdaterPath` in `SelfUpdater`.
     *
     * - Parameter caskUrl: The URL where the Cask file is expected to be located. Redirects will
     *   be followed when retrieving and validating the Cask file.
     *
     * - Parameter isInteractive: Whether user interaction is required when failing to check
     *   or no new update is found. A user usually expects a prompt if they manually searched
     *   for updates.
     */
    public init(
        selfUpdaterName: String,
        selfUpdaterPath: String,
        caskUrl: URL,
        isInteractive: Bool
    ) {
        self.selfUpdaterName = selfUpdaterName
        self.selfUpdaterPath = selfUpdaterPath
        self.caskUrl = caskUrl
        self.isInteractive = isInteractive
    }

    /**
     * Registers a callback that resolves release notes for the update prompt.
     *
     * The callback receives the parsed Cask file, so callers can build a release-notes
     * URL from the version, channel, or any other information encoded in that file.
     * Return `nil` to omit the release-notes button.
     */
    public func resolvingReleaseNotes(with callback: @escaping (NVCaskFile) -> URL?) -> Self {
        self.releaseNotesUrlCallback = callback
        return self
    }

    /**
     * Performs the update check and presents UI when required.
     *
     * This method should usually be called from the main app, not from the helper
     * updater app. It does not install updates directly; installation is handed off
     * to the embedded self-updater.
     */
    public func perform() async {
        guard let caskFile = NVCaskFile.from(url: caskUrl) else {
            Log.text("The contents of the CaskFile at '\(caskUrl.absoluteString)' could not be retrieved.")
            return await presentCouldNotRetrieveUpdate()
        }

        let currentVersion = AppVersion.fromCurrentVersion()

        guard let onlineVersion = AppVersion.from(caskFile.version) else {
            Log.text("The version string from the CaskFile could not be read.")
            return await presentCouldNotRetrieveUpdate()
        }

        Log.text("The latest version read from '\(caskUrl.lastPathComponent)' is: v\(onlineVersion.computerReadable).")
        Log.text("The current version is v\(currentVersion.computerReadable).")

        if onlineVersion > currentVersion {
            // A newer version is available
            await presentNewerVersionAvailable(
                caskFile: caskFile,
                newerVersion: onlineVersion
            )
        } else {
            await presentVersionUpToDate()
        }
    }

    // MARK: - Alerts

    private func presentVersionUpToDate() async {
        Log.text("Application is up-to-date!")

        if isInteractive {
            await Alert.confirm(
                title: Translations.appIsUpToDateTitle
                    .replacingOccurrences(of: "%@", with: Executable.name),
                description: Translations.appIsUpToDateDescription,
                buttonTitle: Translations.buttonOK
            )
        }
    }

    private func presentCouldNotRetrieveUpdate() async {
        Log.text("Could not retrieve update manifest!")

        if isInteractive {
            await Alert.confirm(
                title: Translations.couldNotRetrieveUpdateTitle,
                description: Translations.couldNotRetrieveUpdateDescription,
                buttonTitle: Translations.buttonOK
            )
        }
    }

    private func presentNewerVersionAvailable(
        caskFile: NVCaskFile,
        newerVersion: AppVersion
    ) async {
        Log.text("A newer version is available!")

        let alert = await NVAlert().withInformation(
            title: Translations.updateAvailableTitle
                .replacingOccurrences(of: "%@", with: Executable.name),
            subtitle: Translations.updateAvailableSubtitle
                .replacingOccurrences(of: "%@", with: newerVersion.version),
            description: Translations.updateAvailableDescription
        )
        .withPrimary(
            text: Translations.buttonInstall,
            action: { vc in
                vc.close(with: .OK)
                self.launchSelfUpdater(with: caskFile)
            }
        )
        .withTertiary(text: Translations.buttonDismiss, action: { vc in
            vc.close(with: .OK)
        })

        if let callback = self.releaseNotesUrlCallback,
           let url = callback(caskFile) {
            let _ = await alert.withSecondary(text: Translations.buttonViewReleaseNotes) { _ in
                NSWorkspace.shared.open(url)
            }
        }

        await alert.show(urgency: isInteractive ? .bringToFront : .urgentRequestAttention)
    }

    // MARK: - Functional

    private func launchSelfUpdater(with caskFile: NVCaskFile) {
        let updater = Bundle.main.resourceURL!.path + "/\(selfUpdaterName)"

        // Keep this handoff shell-backed. This is the path that has historically
        // behaved correctly for embedded updater apps and macOS filesystem prompts.
        system_quiet("mkdir -p \(selfUpdaterPath) 2> /dev/null")

        let updaterDirectory = selfUpdaterPath
            .replacingOccurrences(of: "~", with: NSHomeDirectory())

        system_quiet("cp -R \"\(updater)\" \"\(updaterDirectory)/\(selfUpdaterName)\"")

        // The helper app reads this local manifest after launch. The main app does
        // not download or install the update itself.
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
