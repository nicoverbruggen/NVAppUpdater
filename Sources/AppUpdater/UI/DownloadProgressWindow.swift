//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

import SwiftUI
import Cocoa

/**
 Observable state backing the download progress window.
 */
@MainActor
final class DownloadProgress: ObservableObject {
    @Published var bytesWritten: Int64 = 0
    @Published var totalBytes: Int64 = 0

    /// True until we know the expected size, in which case the bar is indeterminate.
    var isIndeterminate: Bool { totalBytes <= 0 }

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesWritten) / Double(totalBytes)
    }
}

struct DownloadProgressView: View {
    @ObservedObject var progress: DownloadProgress
    let appName: String

    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Downloading the latest version of \(appName)…")
                .font(.headline)

            if progress.isIndeterminate {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
            } else {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(LinearProgressViewStyle())
                Text("\(Self.formatter.string(fromByteCount: progress.bytesWritten)) of \(Self.formatter.string(fromByteCount: progress.totalBytes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

/**
 Owns the progress window and only reveals it if the download is still running
 after a delay, so quick downloads never flash a window on screen.
 */
@MainActor
final class DownloadProgressWindowController {
    private let model = DownloadProgress()
    private let appName: String
    private var window: NSWindow?
    private var revealTask: Task<Void, Never>?

    init(appName: String) {
        self.appName = appName
    }

    /// Show the window after `delay` seconds, unless `finish()` is called first.
    func scheduleAppearance(after delay: TimeInterval) {
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.show()
        }
    }

    func update(written: Int64, total: Int64) {
        model.bytesWritten = written
        model.totalBytes = total
    }

    /// Cancel a pending appearance and close the window if it was shown.
    func finish() {
        revealTask?.cancel()
        revealTask = nil
        window?.close()
        window = nil
    }

    private func show() {
        let hosting = NSHostingController(rootView: DownloadProgressView(progress: model, appName: appName))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled]
        window.title = appName
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
