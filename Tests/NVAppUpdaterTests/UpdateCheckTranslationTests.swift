import XCTest
@testable import NVAppUpdater

final class UpdateCheckTranslationTests: XCTestCase {
    func testUpdateCheckTranslationsCanBeOverridden() {
        let original = UpdateCheck.translations.buttonInstall
        defer { UpdateCheck.translations.buttonInstall = original }

        UpdateCheck.translations.buttonInstall = "Upgrade"

        XCTAssertEqual(UpdateCheck.translations.buttonInstall, "Upgrade")
    }

    func testSelfUpdaterTranslationsCanBeOverridden() {
        let original = SelfUpdater.translations.downloadProgressTitle
        let originalManifestURLDescription = SelfUpdater.translations.invalidManifestURLDescription
        defer {
            SelfUpdater.translations.downloadProgressTitle = original
            SelfUpdater.translations.invalidManifestURLDescription = originalManifestURLDescription
        }

        SelfUpdater.translations.downloadProgressTitle = "Downloading..."
        SelfUpdater.translations.invalidManifestURLDescription = "Invalid URL for %@."

        XCTAssertEqual(SelfUpdater.translations.downloadProgressTitle, "Downloading...")
        XCTAssertEqual(SelfUpdater.translations.invalidManifestURLDescription, "Invalid URL for %@.")
    }
}
