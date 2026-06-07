//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

#if DEBUG
import SwiftUI
import Cocoa

struct ProgressWindow_Previews: PreviewProvider {
    static var previews: some View {
        ProgressWindow(
            progress: previewProgress,
            title: "Updating PHP Monitor",
            waitingForSizeText: "Waiting for download size...",
            byteProgressStepIndex: 0,
            contentTopOffset: 0,
            image: NSApp.applicationIconImage
        )
        .previewDisplayName("Downloading")
    }

    @MainActor
    private static var previewProgress: ProgressWindowState {
        let progress = ProgressWindowState(stepTitles: [
            "Downloading update",
            "Extracting update",
            "Restarting PHP Monitor"
        ])
        progress.bytesWritten = 50 * 1024 * 1024
        progress.totalBytes = 100 * 1024 * 1024
        return progress
    }
}
#endif
