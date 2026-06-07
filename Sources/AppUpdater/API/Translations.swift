//
//  Translations.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

extension UpdateCheck {
    /**
     * Text used by the update check UI in the main application.
     *
     * Override these static values before calling `UpdateCheck.perform()` if your app
     * needs localization or custom wording.
     */
    public struct Translations {
        /**
         * Alert title shown when update information could not be retrieved.
         */
        public static var couldNotRetrieveUpdateTitle
            = "Could not retrieve update information."

        /**
         * Alert description shown when update information could not be retrieved.
         */
        public static var couldNotRetrieveUpdateDescription
            = "There was an issue retrieving information about possible updates. This could be a connection or server issue. Check your internet connection and try again later."

        /**
         * Alert title shown when no newer version is available. `%@` is replaced with
         * the application name.
         */
        public static var appIsUpToDateTitle
            = "%@ is up-to-date!"

        /**
         * Alert description shown when no newer version is available.
         */
        public static var appIsUpToDateDescription
            = "The version on the server is not newer than this version, so you're all good."

        /**
         * Alert title shown when an update is available. `%@` is replaced with the
         * application name.
         */
        public static var updateAvailableTitle
            = "An updated version of %@ is available."

        /**
         * Alert subtitle shown when an update is available. `%@` is replaced with the
         * available version.
         */
        public static var updateAvailableSubtitle
            = "Version %@ is available for download."

        /**
         * Alert description shown when an update is available.
         */
        public static var updateAvailableDescription
            = "Do you want to download and install this updated version?"

        /**
         * Primary button title for starting the update.
         */
        public static var buttonInstall = "Install"

        /**
         * Button title for acknowledging informational update-check alerts.
         */
        public static var buttonOK = "OK"

        /**
         * Button title for dismissing the update prompt.
         */
        public static var buttonDismiss = "Dismiss"

        /**
         * Button title for opening release notes when a release-notes callback returns a URL.
         */
        public static var buttonViewReleaseNotes = "View Release Notes"
    }
}

extension SelfUpdater {
    /**
     * Text used by the helper updater app.
     *
     * Override these static values before launching the helper updater if your app
     * needs localization or custom wording.
     */
    public struct Translations {
        /**
         * Progress text shown until the downloader knows the total byte count.
         */
        public static var downloadProgressWaitingForSize = "Waiting for download size..."

        /**
         * Progress text format shown when the downloader knows the current and total
         * byte counts. The first `%@` is replaced with bytes written, and the second
         * `%@` is replaced with total bytes.
         */
        public static var downloadProgressByteCountFormat = "%@ of %@"

        /**
         * Progress window title. `%@` is replaced with the application name.
         */
        public static var progressWindowTitle = "Updating %@"

        /**
         * Status text shown while the update archive is downloading.
         */
        public static var progressStepDownloadingUpdate = "Downloading update"

        /**
         * Status text shown while the downloaded archive is being extracted and validated.
         */
        public static var progressStepExtractingUpdate = "Extracting update"

        /**
         * Status text shown while the app is being restarted. `%@` is replaced with the
         * application name.
         */
        public static var progressStepRestartingApp = "Restarting %@"

        /**
         * Alert description shown when the local update manifest contains an invalid
         * download URL. `%@` is replaced with the application name.
         */
        public static var invalidManifestURLDescription = "The update manifest contains an invalid download URL. Please try searching for updates again in %@."

        /**
         * Alert description shown when the local update manifest cannot be found or
         * parsed. `%@` is replaced with the application name.
         */
        public static var missingManifestDescription = "The manifest file for a potential update was not found. Please try searching for updates again in %@."

        /**
         * Alert description shown when the downloaded archive fails SHA-256 validation.
         */
        public static var checksumValidationFailedDescription = "The downloaded update failed checksum validation. Please try again. If this issue persists, there may be an issue with the server and I do not recommend upgrading."

        /**
         * Alert title shown when the helper updater cannot complete the update. `%@`
         * is replaced with the application name.
         */
        public static var upgradeFailureTitle = "%@ could not be updated."

        /**
         * Button title for acknowledging helper-updater failure alerts.
         */
        public static var buttonOK = "OK"

        /**
         * Alert description shown when the update download fails. `%@` is replaced
         * with the underlying download error.
         */
        public static var downloadFailedDescription = "The update could not be downloaded.\n\n%@\n\nPlease check your internet connection and try again."

        /**
         * Error detail shown when the download exceeds the configured timeout.
         */
        public static var downloadTimedOutDescription = "The download timed out."

        /**
         * Error detail shown when the update server returns a non-successful HTTP
         * status code. `%@` is replaced with the status code.
         */
        public static var downloadUnexpectedStatusDescription = "The server returned an unexpected response (status %@)."

        /**
         * Error detail shown when the downloaded file could not be moved into the
         * updater working directory. `%@` is replaced with the underlying file error.
         */
        public static var downloadFileSaveFailedDescription = "The downloaded file could not be saved: %@"

        /**
         * Alert description shown when the helper updater cannot use its configured
         * working directory. `%@` is replaced with the configured updater path.
         */
        public static var updaterDirectoryMissingDescription = "The updater directory is missing. The automatic updater will quit. Make sure that `%@` is writeable."

        /**
         * Alert description shown when the downloaded archive could not be extracted
         * into a valid app bundle. `%@` is replaced with the configured updater path.
         */
        public static var extractionFailedDescription = "The downloaded file could not be extracted. The automatic updater will quit. Make sure that `%@` is writeable."

        /**
         * Alert description shown when the app being updated does not terminate before
         * the updater timeout expires. `%@` is replaced with the application name.
         */
        public static var terminationFailedDescription = "%@ could not be quit before installing the update. Please quit the app manually and try again."
    }
}
