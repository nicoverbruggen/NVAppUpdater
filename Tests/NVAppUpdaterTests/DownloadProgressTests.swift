import XCTest
@testable import NVAppUpdater

@MainActor
final class DownloadProgressTests: XCTestCase {
    func testKnownTotalReportsDeterminateFraction() {
        let progress = DownloadProgress()
        progress.bytesWritten = 25
        progress.totalBytes = 100

        XCTAssertFalse(progress.isIndeterminate)
        XCTAssertEqual(progress.fractionCompleted, 0.25)
    }

    func testUnknownTotalIsIndeterminate() {
        let progress = DownloadProgress()
        progress.bytesWritten = 25
        progress.totalBytes = NSURLSessionTransferSizeUnknown

        XCTAssertTrue(progress.isIndeterminate)
        XCTAssertEqual(progress.fractionCompleted, 0)
    }
}
