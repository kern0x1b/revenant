import ExpoModulesCore

import Foundation

enum StubReport {
  static func called(_ module: String, _ function: String) {
    NSLog("rn-host: STUB CALLED %@.%@ is a stub in this build; nothing was done", module, function)
  }
}

public final class StubTwoWayAudioModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoTwoWayAudio") }
}

public final class StubHardwareKeyboardModule: Module {
  public func definition() -> ModuleDefinition { Name("PaseoHardwareKeyboard") }
}

public final class StubSQLiteModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoSQLite") }
}
