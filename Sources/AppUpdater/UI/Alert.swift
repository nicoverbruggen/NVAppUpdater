//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa

class Alert {
    public static var appName: String = ""

    // MARK: - Specific Cases

    @MainActor
    public static func upgradeFailure(description: String, shouldExit: Bool = true) async {
        await confirm(
            title: SelfUpdater.Translations.upgradeFailureTitle
                .replacingOccurrences(of: "%@", with: Alert.appName),
            description: description,
            buttonTitle: SelfUpdater.Translations.buttonOK,
            alertStyle: .critical,
            callback: shouldExit ? {
                exit(0)
            } : nil
        )
    }

    // MARK: - Generic

    @MainActor
    public static func confirm(
        title: String,
        description: String,
        buttonTitle: String,
        alertStyle: NSAlert.Style = .informational,
        callback: (() -> Void)? = nil
    ) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = description
        alert.addButton(withTitle: buttonTitle)
        alert.alertStyle = alertStyle
        alert.runModal()
        callback?()
    }

    @MainActor
    public static func choose(
        title: String,
        description: String,
        options: [String],
        cancel: Bool = false
    ) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = description
        for option in options {
            alert.addButton(withTitle: option)
        }
        alert.alertStyle = .informational
        return alert.runModal()
    }
}
