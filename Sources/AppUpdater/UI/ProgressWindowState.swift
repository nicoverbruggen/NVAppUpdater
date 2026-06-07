//
//  Created by Nico Verbruggen on 07/06/2026.
//  Copyright © 2026 Nico Verbruggen. All rights reserved.
//

import Combine
import Foundation

@MainActor
final class ProgressWindowState: ObservableObject {
    @Published var bytesWritten: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published private(set) var stepTitles: [String]
    @Published private(set) var currentStepIndex: Int

    var isIndeterminate: Bool { totalBytes <= 0 }

    var currentStepTitle: String {
        guard stepTitles.indices.contains(currentStepIndex) else { return "" }
        return stepTitles[currentStepIndex]
    }

    init(stepTitles: [String], currentStepIndex: Int = 0) {
        self.stepTitles = stepTitles
        self.currentStepIndex = currentStepIndex
    }

    var fractionCompleted: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(bytesWritten) / Double(totalBytes), 0), 1)
    }

    func advance(toStepAt index: Int) {
        guard stepTitles.indices.contains(index) else { return }
        currentStepIndex = index
    }
}
