//
//  SelfUpdater+Download.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

import Foundation

extension SelfUpdater {
    /**
     * Parses the existing manifest file as declared via the configuration.
     */
    func parseManifest() async -> ReleaseManifest? {
        Log.text("Checking manifest file at \(manifestPath)...")

        do {
            let manifestText = try String(contentsOfFile: manifestPath)
            return try JSONDecoder().decode(ReleaseManifest.self, from: Data(manifestText.utf8))
        } catch {
            Log.text("Parsing the manifest failed (or the manifest file doesn't exist)!")
            await Alert.upgradeFailure(description: Translations.missingManifestDescription
                .replacingOccurrences(of: "%@", with: appName))
        }

        return nil
    }

    /**
     * Validates the download URL from the handoff manifest before any progress UI is shown.
     *
     * A manifest with an invalid URL is treated as a manifest problem, not a download
     * problem, because no network request can be made safely.
     */
    func validateDownloadUrl(from manifest: ReleaseManifest) async -> URL? {
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

    func download(
        _ manifest: ReleaseManifest,
        from url: URL,
        progressWindow: ProgressWindowController
    ) async -> String {
        // Keep this cleanup shell-backed, matching the long-standing updater path
        // that behaves well with macOS application permissions.
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
            try await downloader.download(from: url, to: destination, hardTimeout: downloadTimeout ?? Self.defaultDownloadTimeout)
        } catch {
            await progressWindow.finish()
            Log.text("The update could not be downloaded: \(downloadFailureDescription(for: error))")
            await Alert.upgradeFailure(description: Translations.downloadFailedDescription
                .replacingOccurrences(of: "%@", with: downloadFailureDescription(for: error)))
            return ""
        }

        // Keep checksum validation shell-backed for consistency with the existing
        // updater flow. The empty-output guard handles command failure explicitly.
        let checksum = system("openssl dgst -sha256 \"\(destination.path)\" | awk '{print $NF}'")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !checksum.isEmpty else {
            Log.text("The update checksum could not be calculated.")
            await progressWindow.finish()
            await Alert.upgradeFailure(description: Translations.checksumValidationFailedDescription)
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
            await Alert.upgradeFailure(description: Translations.checksumValidationFailedDescription)
            return ""
        }

        // Return the path to the zip
        return destination.path
    }

    private func downloadFailureDescription(for error: Error) -> String {
        guard let downloadError = error as? DownloadError else {
            return error.localizedDescription
        }

        switch downloadError {
        case .timedOut:
            return Translations.downloadTimedOutDescription
        case .transport(let error):
            return error.localizedDescription
        case .httpStatus(let code):
            return Translations.downloadUnexpectedStatusDescription
                .replacingOccurrences(of: "%@", with: String(code))
        case .fileSystem(let error):
            return Translations.downloadFileSaveFailedDescription
                .replacingOccurrences(of: "%@", with: error.localizedDescription)
        }
    }
}
