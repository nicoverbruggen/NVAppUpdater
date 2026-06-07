//
//  SelfUpdater+Extraction.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

import Foundation

extension SelfUpdater {
    /**
     * Extracts the downloaded archive and verifies that it contains a runnable app bundle.
     *
     * This happens before the running app is terminated, so extraction or validation
     * failures leave the currently installed app untouched.
     */
    func extractAndValidate(
        zipPath: String,
        progressWindow: ProgressWindowController
    ) async -> String {
        // Keep extraction setup shell-backed, matching the updater's known-good
        // filesystem behavior on macOS.
        system_quiet("rm -rf \"\(updaterPath)/extracted\"")
        system_quiet("mkdir -p \"\(updaterPath)/extracted\"")

        // Make sure the updater directory exists
        var isDirectory: ObjCBool = true
        if !FileManager.default.fileExists(atPath: "\(updaterPath)/extracted", isDirectory: &isDirectory)
            || !isDirectory.boolValue {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: Translations.updaterDirectoryMissingDescription
                .replacingOccurrences(of: "%@", with: selfUpdaterPath))
            return ""
        }

        // Use the system unzip command so archives are expanded through the same
        // path the updater has historically used.
        system_quiet("unzip \"\(zipPath)\" -d \"\(updaterPath)/extracted\"")

        // Find the .app file
        guard let appURL = extractedAppURL() else {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: Translations.extractionFailedDescription
                .replacingOccurrences(of: "%@", with: selfUpdaterPath))
            return ""
        }

        Log.text("Finished extracting: \(appURL.path)")

        // Make sure the file was extracted
        guard isValidApplication(at: appURL) else {
            await progressWindow.finish()
            await Alert.upgradeFailure(description: Translations.extractionFailedDescription
                .replacingOccurrences(of: "%@", with: selfUpdaterPath))
            return ""
        }

        return appURL.path
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
        // A directory ending in .app is not enough; require a bundle and executable
        // before the installed app is terminated and replaced.
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
