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
