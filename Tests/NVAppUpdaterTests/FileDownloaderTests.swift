import XCTest
@testable import NVAppUpdater

final class FileDownloaderTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testDownloadWritesSuccessfulHTTPResponseToDestination() async throws {
        let payload = Data("downloaded update".utf8)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "\(payload.count)"]
            )!

            return (response, payload)
        }

        let destination = temporaryDestination()
        let downloader = FileDownloader(
            onProgress: { _, _ in },
            configuration: makeStubConfiguration
        )

        try await downloader.download(
            from: URL(string: "https://example.com/update.zip")!,
            to: destination
        )

        XCTAssertEqual(try Data(contentsOf: destination), payload)
    }

    func testDownloadReportsProgress() async throws {
        let payload = Data(repeating: 7, count: 128 * 1024)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "\(payload.count)"]
            )!

            return (response, payload)
        }

        let progress = ProgressRecorder()
        let downloader = FileDownloader(
            onProgress: progress.record(written:total:),
            configuration: makeStubConfiguration
        )

        try await downloader.download(
            from: URL(string: "https://example.com/update.zip")!,
            to: temporaryDestination()
        )

        XCTAssertTrue(progress.events.contains { event in
            event.written == Int64(payload.count)
                && event.total == Int64(payload.count)
        })
    }

    func testDownloadThrowsHTTPStatusForNonSuccessfulResponse() async throws {
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!

            return (response, Data("not found".utf8))
        }

        let downloader = FileDownloader(
            onProgress: { _, _ in },
            configuration: makeStubConfiguration
        )

        do {
            try await downloader.download(
                from: URL(string: "https://example.com/missing.zip")!,
                to: temporaryDestination()
            )
            XCTFail("Expected the download to fail with an HTTP status error.")
        } catch DownloadError.httpStatus(let statusCode) {
            XCTAssertEqual(statusCode, 404)
        } catch {
            XCTFail("Expected HTTP status error, got \(error).")
        }
    }

    func testTimedOutURLErrorIsMappedToDownloadTimeout() async throws {
        StubURLProtocol.handler = { _ in
            throw URLError(.timedOut)
        }

        let downloader = FileDownloader(
            onProgress: { _, _ in },
            configuration: makeStubConfiguration
        )

        do {
            try await downloader.download(
                from: URL(string: "https://example.com/update.zip")!,
                to: temporaryDestination()
            )
            XCTFail("Expected the download to fail with a timeout.")
        } catch DownloadError.timedOut {
            // Expected.
        } catch {
            XCTFail("Expected timeout error, got \(error).")
        }
    }

    func testTransportErrorIsPreserved() async throws {
        StubURLProtocol.handler = { _ in
            throw URLError(.cannotFindHost)
        }

        let downloader = FileDownloader(
            onProgress: { _, _ in },
            configuration: makeStubConfiguration
        )

        do {
            try await downloader.download(
                from: URL(string: "https://example.com/update.zip")!,
                to: temporaryDestination()
            )
            XCTFail("Expected the download to fail with a transport error.")
        } catch DownloadError.transport(let error as URLError) {
            XCTAssertEqual(error.code, .cannotFindHost)
        } catch {
            XCTFail("Expected transport error, got \(error).")
        }
    }

    func testFileSystemErrorIsReportedWhenDestinationCannotBeWritten() async throws {
        let payload = Data("downloaded update".utf8)
        StubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "\(payload.count)"]
            )!

            return (response, payload)
        }

        let missingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let unwritableDestination = missingDirectory.appendingPathComponent("update.zip")
        let downloader = FileDownloader(
            onProgress: { _, _ in },
            configuration: makeStubConfiguration
        )

        do {
            try await downloader.download(
                from: URL(string: "https://example.com/update.zip")!,
                to: unwritableDestination
            )
            XCTFail("Expected the download to fail with a file-system error.")
        } catch DownloadError.fileSystem {
            // Expected.
        } catch {
            XCTFail("Expected file-system error, got \(error).")
        }
    }

    private func temporaryDestination() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
    }

    private func makeStubConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }
}

private final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class ProgressRecorder {
    private let lock = NSLock()
    private(set) var events: [(written: Int64, total: Int64)] = []

    func record(written: Int64, total: Int64) {
        lock.lock()
        events.append((written, total))
        lock.unlock()
    }
}
