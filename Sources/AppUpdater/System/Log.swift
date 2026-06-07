//
//  Created by Nico Verbruggen on 30/05/2024.
//  Copyright © 2024 Nico Verbruggen. All rights reserved.
//

import Foundation

open class Log {
    public static func text(_ text: String) {
        self.handler(text)
    }

    public static var handler: (_ text: String) -> Void = { text in 
        print(text)
    }
}
