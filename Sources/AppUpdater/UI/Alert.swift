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
            title: "\(Alert.appName) could not be updated.",
            description: description,
            alertStyle: .critical,
            callback: {
                exit(0)
            }
        )
    }

    // MARK: - Generic

    @MainActor
    public static func confirm(
        title: String,
        description: String,
        alertStyle: NSAlert.Style = .informational,
        callback: (() -> Void)? = nil
    ) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = description
        alert.addButton(withTitle: "OK")
        alert.alertStyle = alertStyle
        alert.runModal()
        if callback != nil {
            callback!()
        }
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

