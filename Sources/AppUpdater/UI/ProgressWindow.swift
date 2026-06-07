//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

import SwiftUI
import Cocoa

struct ProgressWindow: View {
    @ObservedObject var progress: ProgressWindowState
    let title: String
    let waitingForSizeText: String
    let byteCountFormat: String
    let byteProgressStepIndex: Int?
    let contentTopOffset: CGFloat
    let image: NSImage

    private let progressAreaHeight: CGFloat = 34

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
                .padding(.top, -5)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(progress.currentStepTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                progressContent
                    .frame(minHeight: progressAreaHeight, alignment: .top)
            }
        }
        .padding(24)
        .padding(.top, -contentTopOffset)
        .frame(width: 480)
    }

    @ViewBuilder
    private var progressContent: some View {
        if byteProgressStepIndex == progress.currentStepIndex {
            byteProgress
        } else {
            ProgressView()
                .progressViewStyle(LinearProgressViewStyle())
        }
    }

    @ViewBuilder
    private var byteProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progress.isIndeterminate {
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle())
                Text(waitingForSizeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(LinearProgressViewStyle())
                HStack(alignment: .firstTextBaseline) {
                    Text(String(
                        format: byteCountFormat,
                        Self.formatter.string(fromByteCount: progress.bytesWritten),
                        Self.formatter.string(fromByteCount: progress.totalBytes)
                    ))
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
