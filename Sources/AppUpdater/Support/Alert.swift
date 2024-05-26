//
//  Created by Nico Verbruggen on 26/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation
import Cocoa

class Alert {
    public static var appName: String = ""

    public static func show(description: String, shouldExit: Bool = true) async {
        await withUnsafeContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "\(Alert.appName) could not be updated."
                alert.informativeText = description
                alert.addButton(withTitle: "OK")
                alert.alertStyle = .critical
                alert.runModal()
                if shouldExit {
                    exit(0)
                }
                continuation.resume()
            }
        }
    }
}

