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
        return min(max(Double(bytesWritten) / Double(totalBytes), 0), 1)
    }
}

struct DownloadProgressView: View {
    @ObservedObject var progress: DownloadProgress
    let appName: String
    let image: NSImage

    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 46, height: 46)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SelfUpdater.translations.downloadProgressTitle)
                        .font(.headline)
                    Text(appName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if progress.isIndeterminate {
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle())
                        Text(SelfUpdater.translations.downloadProgressWaitingForSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView(value: progress.fractionCompleted)
                            .progressViewStyle(LinearProgressViewStyle())
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Self.formatter.string(fromByteCount: progress.bytesWritten)) of \(Self.formatter.string(fromByteCount: progress.totalBytes))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int((progress.fractionCompleted * 100).rounded()))%")
                                .font(.system(.caption, design: .monospaced).weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

#if DEBUG
struct DownloadProgressView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadProgressView(
            progress: previewProgress,
            appName: "PHP Monitor",
            image: NSApp.applicationIconImage
        )
            .previewDisplayName("Downloading")
    }

    @MainActor
    private static var previewProgress: DownloadProgress {
        let progress = DownloadProgress()
        progress.bytesWritten = 50 * 1024 * 1024
        progress.totalBytes = 100 * 1024 * 1024
        return progress
    }
}
#endif

/**
 Owns the progress window and only reveals it if the download is still running
 after a delay, so quick downloads never flash a window on screen.
 */
@MainActor
final class DownloadProgressWindowController {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("NVAppUpdater.DownloadProgressWindow")

    private let model = DownloadProgress()
    private let appName: String
    private let image: NSImage?
    private var window: NSWindow?
    private var revealTask: Task<Void, Never>?

    init(appName: String, image: NSImage? = nil) {
        self.appName = appName
        self.image = image
    }

    /// Show the window after `delay` seconds, unless `finish()` is called first.
    func scheduleAppearance(after delay: TimeInterval) {
        revealTask?.cancel()
        revealTask = nil

        if delay <= 0 {
            show()
            return
        }

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
        let hosting = NSHostingController(
            rootView: DownloadProgressView(
                progress: model,
                appName: appName,
                image: image ?? NSApp.applicationIconImage
            )
        )
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled]
        window.identifier = Self.windowIdentifier
        window.title = ""
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
