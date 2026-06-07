import XCTest
@testable import NVAppUpdater

final class UpdateCheckTranslationTests: XCTestCase {
    func testUpdateCheckTranslationsCanBeOverridden() {
        let original = UpdateCheck.Translations.buttonInstall
        defer { UpdateCheck.Translations.buttonInstall = original }

        UpdateCheck.Translations.buttonInstall = "Upgrade"

        XCTAssertEqual(UpdateCheck.Translations.buttonInstall, "Upgrade")
    }

    func testSelfUpdaterTranslationsCanBeOverridden() {
        let originalProgressWindowTitle = SelfUpdater.Translations.progressWindowTitle
        let originalProgressStepExtractingUpdate = SelfUpdater.Translations.progressStepExtractingUpdate
        let originalProgressStepRestartingApp = SelfUpdater.Translations.progressStepRestartingApp
        let originalManifestURLDescription = SelfUpdater.Translations.invalidManifestURLDescription
        defer {
            SelfUpdater.Translations.progressWindowTitle = originalProgressWindowTitle
            SelfUpdater.Translations.progressStepExtractingUpdate = originalProgressStepExtractingUpdate
            SelfUpdater.Translations.progressStepRestartingApp = originalProgressStepRestartingApp
            SelfUpdater.Translations.invalidManifestURLDescription = originalManifestURLDescription
        }

        SelfUpdater.Translations.progressWindowTitle = "Updating %@..."
        SelfUpdater.Translations.progressStepExtractingUpdate = "Unpacking update"
        SelfUpdater.Translations.progressStepRestartingApp = "Restarting %@"
        SelfUpdater.Translations.invalidManifestURLDescription = "Invalid URL for %@."

        XCTAssertEqual(SelfUpdater.Translations.progressWindowTitle, "Updating %@...")
        XCTAssertEqual(SelfUpdater.Translations.progressStepExtractingUpdate, "Unpacking update")
        XCTAssertEqual(SelfUpdater.Translations.progressStepRestartingApp, "Restarting %@")
        XCTAssertEqual(SelfUpdater.Translations.invalidManifestURLDescription, "Invalid URL for %@.")
    }
}
