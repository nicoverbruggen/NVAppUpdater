//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

import Foundation

/**
 The distinct ways a download can fail. This lets the caller tell a failed
 *download* apart from a completed download that fails checksum validation.
 */
enum DownloadError: LocalizedError {
    case invalidURL
    case timedOut
    case transport(Error)
    case httpStatus(Int)
    case fileSystem(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The update URL in the manifest is invalid."
        case .timedOut:
            return "The download timed out."
        case .transport(let error):
            return error.localizedDescription
        case .httpStatus(let code):
            return "The server returned an unexpected response (status \(code))."
        case .fileSystem(let error):
            return "The downloaded file could not be saved: \(error.localizedDescription)"
        }
    }
}

/**
 Downloads a file with `URLSession` and reports progress.

 Uses a delegate-based `URLSessionDownloadTask` (rather than the async
 `download(from:)`, which requires macOS 12) so it works on the macOS 11
 deployment target while still surfacing byte-level progress.

 Timeouts are stall-based rather than wall-clock: `timeoutIntervalForRequest`
 resets every time new data arrives, so slow-but-progressing downloads are not
 killed, while a genuinely stalled transfer still fails.
 */
final class FileDownloader: NSObject {

    /// Called on a background queue with (bytes written so far, total expected).
    /// `total` is `NSURLSessionTransferSizeUnknown` (-1) when the size is unknown.
    private let onProgress: (_ written: Int64, _ total: Int64) -> Void
    private let configurationFactory: () -> URLSessionConfiguration

    private var continuation: CheckedContinuation<Void, Error>?
    private var destination: URL!

    init(
        onProgress: @escaping (_ written: Int64, _ total: Int64) -> Void,
        configuration: @escaping () -> URLSessionConfiguration = { .ephemeral }
    ) {
        self.onProgress = onProgress
        self.configurationFactory = configuration
        super.init()
    }

    func download(
        from url: URL,
        to destination: URL,
        stallTimeout: TimeInterval = 30,
        hardTimeout: TimeInterval? = nil
    ) async throws {
        self.destination = destination

        let config = configurationFactory()
        // Stall timeout: resets every time new data arrives, so a slow-but-
        // progressing download is not killed.
        config.timeoutIntervalForRequest = stallTimeout
        // Hard timeout: an absolute ceiling on the whole transfer (including any
        // waitsForConnectivity wait). When the caller doesn't set one, fall back
        // to URLSession's default so only the stall timeout is effective.
        if let hardTimeout {
            config.timeoutIntervalForResource = hardTimeout
        }
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }
}

extension FileDownloader: URLSessionDownloadDelegate {

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // An HTTP error (e.g. 404) still "finishes" from URLSession's point of view,
        // so validate the status here before treating the file as a real download.
        if let response = downloadTask.response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            resume(throwing: .httpStatus(response.statusCode))
            return
        }

        // The temp file is deleted as soon as this method returns, so it must be
        // moved into place synchronously here.
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            resume(returning: ())
        } catch {
            resume(throwing: .fileSystem(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // On success this fires with a nil error after didFinishDownloadingTo has
        // already resumed the continuation, so only act on actual failures.
        guard let error = error else { return }
        // Both the stall timeout and the hard timeout surface as URLError.timedOut.
        if let urlError = error as? URLError, urlError.code == .timedOut {
            resume(throwing: .timedOut)
        } else {
            resume(throwing: .transport(error))
        }
    }

    private func resume(returning value: Void) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    private func resume(throwing error: DownloadError) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
