import ExpoModulesCore

import Foundation

enum StubReport {
  static func called(_ module: String, _ function: String) {
    NSLog("rn-host: STUB CALLED %@.%@ is a stub in this build; nothing was done", module, function)
  }
}

