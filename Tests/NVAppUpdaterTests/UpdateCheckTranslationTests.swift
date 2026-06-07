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
        defer { SelfUpdater.translations.downloadProgressTitle = original }

        SelfUpdater.translations.downloadProgressTitle = "Downloading..."

        XCTAssertEqual(SelfUpdater.translations.downloadProgressTitle, "Downloading...")
    }
}
