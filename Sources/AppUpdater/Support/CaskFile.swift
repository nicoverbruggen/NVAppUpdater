//
//  Created by Nico Verbruggen on 30/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation

public struct CaskFile {
    var properties: [String: String]

    var name: String { return self.properties["name"]! }
    var url: String { return self.properties["url"]! }
    var sha256: String { return self.properties["sha256"]! }
    var version: String { return self.properties["version"]! }

    static func from(url: URL) -> CaskFile? {
        var string: String?

        if url.scheme == "file" {
            string = try? String(contentsOf: url)
        } else {
            string = system("curl -s --max-time 10 '\(url.absoluteString)'")
        }

        guard let string else {
            Log.text("The content of the URL for the CaskFile could not be retrieved")
            return nil
        }

        let lines = string.split(separator: "\n")
            .map { line in
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0 != "" }

        if lines.count < 4 {
            Log.text("The CaskFile is <4 lines long, which is too short")
            return nil
        }

        if !lines.first!.starts(with: "cask") || !lines.last!.starts(with: "end") {
            Log.text("The CaskFile does not start with 'cask' or does not end with 'end'")
            return nil
        }

        var props: [String: String] = [:]

        let regex = try! NSRegularExpression(pattern: "(\\w+)\\s+'([^']+)'")

        for line in lines {
            if let match = regex.firstMatch(
                in: String(line),
                range: NSRange(location: 0, length: line.utf16.count)
            ) {
                let keyRange = match.range(at: 1)
                let valueRange = match.range(at: 2)
                let key = (line as NSString).substring(with: keyRange)
                let value = (line as NSString).substring(with: valueRange)
                props[key] = value
            }
        }

        for required in ["version", "sha256", "url", "name"] where !props.keys.contains(required) {
            Log.text("Property '\(required)' expected on CaskFile, assuming CaskFile is invalid")
            return nil
        }

        return CaskFile(properties: props)
    }
}
