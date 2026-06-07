//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

import SwiftUI
import Cocoa

@MainActor
final class ProgressWindowController {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("NVAppUpdater.ProgressWindow")
    static let titlebarContentOffset: CGFloat = 32

    let state: ProgressWindowState
    private(set) var contentTopOffset: CGFloat = titlebarContentOffset

    private let title: String
    private let waitingForSizeText: String
    private let byteCountFormat: String
    private let byteProgressStepIndex: Int?
    private let image: NSImage?
    private var window: NSWindow?
    private var revealTask: Task<Void, Never>?

    init(
        title: String,
        stepTitles: [String],
        waitingForSizeText: String,
        byteCountFormat: String = SelfUpdater.Translations.downloadProgressByteCountFormat,
        byteProgressStepIndex: Int? = nil,
        image: NSImage? = nil
    ) {
        self.state = ProgressWindowState(stepTitles: stepTitles)
        self.title = title
        self.waitingForSizeText = waitingForSizeText
        self.byteCountFormat = byteCountFormat
        self.byteProgressStepIndex = byteProgressStepIndex
        self.image = image
    }

    func show() {
        revealTask?.cancel()
        revealTask = nil

        if let window {
            window.makeKeyAndOrderFront(nil)
            window.setCenterPosition(offsetY: 70)
            return
        }

        let hosting = NSHostingController(rootView: makeRootView())
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .fullSizeContentView]
        window.identifier = Self.windowIdentifier
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.level = .floating

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        hosting.view.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        window.setCenterPosition(offsetY: 70)

        self.window = window
    }

    private func makeRootView() -> ProgressWindow {
        ProgressWindow(
            progress: state,
            title: title,
            waitingForSizeText: waitingForSizeText,
            byteCountFormat: byteCountFormat,
            byteProgressStepIndex: byteProgressStepIndex,
            contentTopOffset: contentTopOffset,
            image: image ?? NSApp.applicationIconImage
        )
    }

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
        state.bytesWritten = written
        state.totalBytes = total
    }

    func advance(toStepAt index: Int) {
        state.advance(toStepAt: index)
    }

    func finish() {
        revealTask?.cancel()
        revealTask = nil
        window?.close()
        window = nil
    }
}

private extension NSWindow {
    func setCenterPosition(offsetY: CGFloat = 0) {
        guard let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            return
        }

        setFrameOrigin(NSPoint(
            x: visibleFrame.midX - frame.size.width / 2,
            y: visibleFrame.midY - frame.size.height / 2 + offsetY
        ))
    }
}
