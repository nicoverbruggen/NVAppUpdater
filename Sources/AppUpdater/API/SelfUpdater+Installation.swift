//
//  SelfUpdater+Installation.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

import Foundation

extension SelfUpdater {
    /**
     * Replaces the installed app with the already extracted update.
     *
     * This runs after download, checksum validation, extraction, app-bundle validation,
     * and termination of the running app. The filesystem operations stay shell-backed
     * to preserve the updater path that has worked reliably with macOS permissions.
     */
    func installExtractedApp(at extractedAppPath: String, zipPath: String) async -> String {
        let app = URL(fileURLWithPath: extractedAppPath).lastPathComponent

        Log.text("Removing \(app) before replacing...")
        system_quiet("rm -rf \"/Applications/\(app)\"")

        system_quiet("mv \"\(extractedAppPath)\" \"/Applications/\(app)\"")

        // Clean up the one-shot handoff files after the update has been installed.
        system_quiet("rm \"\(zipPath)\"")
        system_quiet("rm \"\(manifestPath)\"")

        // Write a file that is only written when we upgraded successfully
        system_quiet("touch \"\(updaterPath)/upgrade.success\"")

        // Return the new location of the app
        return "/Applications/\(app)"
    }
}
