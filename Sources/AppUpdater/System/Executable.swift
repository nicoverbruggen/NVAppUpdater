//
//  Created by Nico Verbruggen on 30/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation

class Executable {
    static var name: String {
        Bundle.main.infoDictionary?["CFBundleName"] as! String
    }

    static var identifier: String {
        Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String
    }

    static var fullVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        return "\(version) (\(build))"
    }

    static var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }

    static var shortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }
}
