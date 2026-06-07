//
//  Translations.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

extension UpdateCheck {
    /**
     * Translations that can be overridden.
     */
    public struct translations {
        public static var couldNotRetrieveUpdateTitle
            = "Could not retrieve update information."

        public static var couldNotRetrieveUpdateDescription
            = "There was an issue retrieving information about possible updates. This could be a connection or server issue. Check your internet connection and try again later."

        public static var appIsUpToDateTitle
            = "%@ is up-to-date!"

        public static var appIsUpToDateDescription
            = "The version on the server is not newer than this version, so you're all good."

        public static var updateAvailableTitle
            = "An updated version of %@ is available."

        public static var updateAvailableSubtitle
            = "Version %@ is available for download."

        public static var updateAvailableDescription
            = "Do you want to download and install this updated version?"

        public static var buttonInstall = "Install"
        public static var buttonDismiss = "Dismiss"
        public static var buttonViewReleaseNotes = "View Release Notes"
    }
}

extension SelfUpdater {
    /**
     * Translations that can be overridden.
     */
    public struct translations {
        public static var downloadProgressTitle = "Downloading update, please wait.."
        public static var downloadProgressWaitingForSize = "Waiting for download size..."
        public static var invalidManifestURLDescription = "The update manifest contains an invalid download URL. Please try searching for updates again in %@."
    }
}
