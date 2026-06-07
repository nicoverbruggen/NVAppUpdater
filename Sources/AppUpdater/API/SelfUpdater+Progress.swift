//
//  SelfUpdater+Progress.swift
//  NVAppUpdater
//
//  Created by Nico Verbruggen on 07/06/2026.
//

extension SelfUpdater {
    enum ProgressStep: Int, CaseIterable {
        case downloadingUpdate
        case extractingUpdate
        case restartingApplication
    }

    @MainActor
    func makeProgressWindow() -> ProgressWindowController {
        ProgressWindowController(
            title: Self.formatted(Translations.progressWindowTitle, appName: appName),
            stepTitles: Self.progressStepTitles(appName: appName),
            waitingForSizeText: Translations.downloadProgressWaitingForSize,
            byteCountFormat: Translations.downloadProgressByteCountFormat,
            byteProgressStepIndex: ProgressStep.downloadingUpdate.rawValue,
            image: downloadProgressImage
        )
    }

    static func progressStepTitles(appName: String) -> [String] {
        [
            Translations.progressStepDownloadingUpdate,
            Translations.progressStepExtractingUpdate,
            formatted(Translations.progressStepRestartingApp, appName: appName)
        ]
    }

    func show(_ progressWindow: ProgressWindowController) async {
        switch progressWindowDisplayMode {
        case .always:
            await progressWindow.show()
        case .whenUpdatingTakesLongerThan(let delay):
            await progressWindow.scheduleAppearance(after: delay)
        }
    }

    private static func formatted(_ string: String, appName: String) -> String {
        string.replacingOccurrences(of: "%@", with: appName)
    }
}
