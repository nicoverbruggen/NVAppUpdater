import XCTest
@testable import NVAppUpdater

final class UpdateCheckTranslationTests: XCTestCase {
    func testUpdateCheckTranslationsCanBeOverridden() {
        let originalButtonInstall = UpdateCheck.Translations.buttonInstall
        let originalButtonOK = UpdateCheck.Translations.buttonOK
        defer {
            UpdateCheck.Translations.buttonInstall = originalButtonInstall
            UpdateCheck.Translations.buttonOK = originalButtonOK
        }

        UpdateCheck.Translations.buttonInstall = "Upgrade"
        UpdateCheck.Translations.buttonOK = "Got It"

        XCTAssertEqual(UpdateCheck.Translations.buttonInstall, "Upgrade")
        XCTAssertEqual(UpdateCheck.Translations.buttonOK, "Got It")
    }

    func testSelfUpdaterTranslationsCanBeOverridden() {
        let originalButtonOK = SelfUpdater.Translations.buttonOK
        let originalProgressWindowTitle = SelfUpdater.Translations.progressWindowTitle
        let originalDownloadProgressByteCountFormat = SelfUpdater.Translations.downloadProgressByteCountFormat
        let originalProgressStepExtractingUpdate = SelfUpdater.Translations.progressStepExtractingUpdate
        let originalProgressStepRestartingApp = SelfUpdater.Translations.progressStepRestartingApp
        let originalManifestURLDescription = SelfUpdater.Translations.invalidManifestURLDescription
        let originalMissingManifestDescription = SelfUpdater.Translations.missingManifestDescription
        let originalChecksumValidationFailedDescription = SelfUpdater.Translations.checksumValidationFailedDescription
        let originalUpgradeFailureTitle = SelfUpdater.Translations.upgradeFailureTitle
        let originalDownloadFailedDescription = SelfUpdater.Translations.downloadFailedDescription
        let originalDownloadTimedOutDescription = SelfUpdater.Translations.downloadTimedOutDescription
        let originalDownloadUnexpectedStatusDescription = SelfUpdater.Translations.downloadUnexpectedStatusDescription
        let originalDownloadFileSaveFailedDescription = SelfUpdater.Translations.downloadFileSaveFailedDescription
        let originalUpdaterDirectoryMissingDescription = SelfUpdater.Translations.updaterDirectoryMissingDescription
        let originalExtractionFailedDescription = SelfUpdater.Translations.extractionFailedDescription
        let originalTerminationFailedDescription = SelfUpdater.Translations.terminationFailedDescription
        defer {
            SelfUpdater.Translations.buttonOK = originalButtonOK
            SelfUpdater.Translations.progressWindowTitle = originalProgressWindowTitle
            SelfUpdater.Translations.downloadProgressByteCountFormat = originalDownloadProgressByteCountFormat
            SelfUpdater.Translations.progressStepExtractingUpdate = originalProgressStepExtractingUpdate
            SelfUpdater.Translations.progressStepRestartingApp = originalProgressStepRestartingApp
            SelfUpdater.Translations.invalidManifestURLDescription = originalManifestURLDescription
            SelfUpdater.Translations.missingManifestDescription = originalMissingManifestDescription
            SelfUpdater.Translations.checksumValidationFailedDescription = originalChecksumValidationFailedDescription
            SelfUpdater.Translations.upgradeFailureTitle = originalUpgradeFailureTitle
            SelfUpdater.Translations.downloadFailedDescription = originalDownloadFailedDescription
            SelfUpdater.Translations.downloadTimedOutDescription = originalDownloadTimedOutDescription
            SelfUpdater.Translations.downloadUnexpectedStatusDescription = originalDownloadUnexpectedStatusDescription
            SelfUpdater.Translations.downloadFileSaveFailedDescription = originalDownloadFileSaveFailedDescription
            SelfUpdater.Translations.updaterDirectoryMissingDescription = originalUpdaterDirectoryMissingDescription
            SelfUpdater.Translations.extractionFailedDescription = originalExtractionFailedDescription
            SelfUpdater.Translations.terminationFailedDescription = originalTerminationFailedDescription
        }

        SelfUpdater.Translations.buttonOK = "Close"
        SelfUpdater.Translations.progressWindowTitle = "Updating %@..."
        SelfUpdater.Translations.downloadProgressByteCountFormat = "%@ / %@"
        SelfUpdater.Translations.progressStepExtractingUpdate = "Unpacking update"
        SelfUpdater.Translations.progressStepRestartingApp = "Restarting %@"
        SelfUpdater.Translations.invalidManifestURLDescription = "Invalid URL for %@."
        SelfUpdater.Translations.missingManifestDescription = "Missing manifest for %@."
        SelfUpdater.Translations.checksumValidationFailedDescription = "Checksum failed."
        SelfUpdater.Translations.upgradeFailureTitle = "%@ failed."
        SelfUpdater.Translations.downloadFailedDescription = "Download failed: %@."
        SelfUpdater.Translations.downloadTimedOutDescription = "Timed out."
        SelfUpdater.Translations.downloadUnexpectedStatusDescription = "HTTP %@."
        SelfUpdater.Translations.downloadFileSaveFailedDescription = "Save failed: %@."
        SelfUpdater.Translations.updaterDirectoryMissingDescription = "Directory missing: %@."
        SelfUpdater.Translations.extractionFailedDescription = "Extraction failed: %@."
        SelfUpdater.Translations.terminationFailedDescription = "%@ did not quit."

        XCTAssertEqual(SelfUpdater.Translations.buttonOK, "Close")
        XCTAssertEqual(SelfUpdater.Translations.progressWindowTitle, "Updating %@...")
        XCTAssertEqual(SelfUpdater.Translations.downloadProgressByteCountFormat, "%@ / %@")
        XCTAssertEqual(SelfUpdater.Translations.progressStepExtractingUpdate, "Unpacking update")
        XCTAssertEqual(SelfUpdater.Translations.progressStepRestartingApp, "Restarting %@")
        XCTAssertEqual(SelfUpdater.Translations.invalidManifestURLDescription, "Invalid URL for %@.")
        XCTAssertEqual(SelfUpdater.Translations.missingManifestDescription, "Missing manifest for %@.")
        XCTAssertEqual(SelfUpdater.Translations.checksumValidationFailedDescription, "Checksum failed.")
        XCTAssertEqual(SelfUpdater.Translations.upgradeFailureTitle, "%@ failed.")
        XCTAssertEqual(SelfUpdater.Translations.downloadFailedDescription, "Download failed: %@.")
        XCTAssertEqual(SelfUpdater.Translations.downloadTimedOutDescription, "Timed out.")
        XCTAssertEqual(SelfUpdater.Translations.downloadUnexpectedStatusDescription, "HTTP %@.")
        XCTAssertEqual(SelfUpdater.Translations.downloadFileSaveFailedDescription, "Save failed: %@.")
        XCTAssertEqual(SelfUpdater.Translations.updaterDirectoryMissingDescription, "Directory missing: %@.")
        XCTAssertEqual(SelfUpdater.Translations.extractionFailedDescription, "Extraction failed: %@.")
        XCTAssertEqual(SelfUpdater.Translations.terminationFailedDescription, "%@ did not quit.")
    }
}
