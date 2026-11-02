import ExpoModulesCore

import Foundation

enum StubReport {
  static func called(_ module: String, _ function: String) {
    NSLog("rn-host: STUB CALLED %@.%@ is a stub in this build; nothing was done", module, function)
  }
}

public final class StubAudioModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoAudio")
    Class("AudioPlayer") {
      Constructor { () in }
      Function("replace") { () in StubReport.called("ExpoAudio", "replace") }
      Function("setPlaybackRate") { () in StubReport.called("ExpoAudio", "setPlaybackRate") }
    }
    Class("AudioRecorder") {
      Constructor { () in }
      AsyncFunction("prepareToRecordAsync") { () in StubReport.called("ExpoAudio", "prepareToRecordAsync") }
    }
    Class("AudioPlaylist") {
      Constructor { () in }
    }
    Class("AudioStream") {
      Constructor { () in }
    }
    AsyncFunction("setAudioModeAsync") { () in StubReport.called("ExpoAudio", "setAudioModeAsync") }
    AsyncFunction("setIsAudioActiveAsync") { () in StubReport.called("ExpoAudio", "setIsAudioActiveAsync") }
  }
}

public final class StubDocumentPickerModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoDocumentPicker") }
}

public final class StubHapticsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoHaptics")
    AsyncFunction("notificationAsync") { (_: String) in StubReport.called("ExpoHaptics", "notificationAsync") }
    AsyncFunction("impactAsync") { (_: String) in StubReport.called("ExpoHaptics", "impactAsync") }
    AsyncFunction("selectionAsync") { StubReport.called("ExpoHaptics", "selectionAsync") }
  }
}

public final class StubImagePickerModule: Module {
  public func definition() -> ModuleDefinition { Name("ExponentImagePicker") }
}

public final class StubSharingModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoSharing") }
}

public final class StubSplashScreenModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoSplashScreen")
    AsyncFunction("hide") { StubReport.called("ExpoSplashScreen", "hide") }
    Function("preventAutoHide") { StubReport.called("ExpoSplashScreen", "preventAutoHide") }
  }
}

public final class StubClipboardModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoClipboard")
    AsyncFunction("getStringAsync") { (_: [String: Any]) -> String in UIPasteboard.general.string ?? "" }
    AsyncFunction("setStringAsync") { (text: String, _: [String: Any]) -> Bool in
      UIPasteboard.general.string = text
      return true
    }
  }
}

public final class StubFileSystemModule: Module {
  public func definition() -> ModuleDefinition {
    Name("FileSystem")
    Constants {
      let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
      let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? ""
      return [
        "documentDirectory": "file://" + documents + "/",
        "cacheDirectory": "file://" + caches + "/",
        "bundleDirectory": "file://" + Bundle.main.bundlePath + "/"
      ]
    }
    Class("FileSystemFile") { Constructor { () in } }
    Class("FileSystemDirectory") { Constructor { () in } }
    Class("FileSystemDownloadTask") { Constructor { () in } }
    Class("FileSystemUploadTask") { Constructor { () in } }
    Class("FileSystemWatcher") { Constructor { () in } }
  }
}

public final class StubFontLoaderModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoFontLoader")
    Function("getLoadedFonts") { () -> [String] in [] }
    AsyncFunction("loadAsync") { (_: String, _: String) in StubReport.called("ExpoFontLoader", "loadAsync") }
  }
}

public final class StubFontUtilsModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoFontUtils") }
}

public final class StubTwoWayAudioModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoTwoWayAudio") }
}

public final class StubHardwareKeyboardModule: Module {
  public func definition() -> ModuleDefinition { Name("PaseoHardwareKeyboard") }
}

public final class StubBackgroundNotificationTasksModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoBackgroundNotificationTasksModule") }
}

public final class StubBadgeModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoBadgeModule") }
}

public final class StubCameraModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoCamera") }
}

public final class StubImageManipulatorModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoImageManipulator") }
}

public final class StubNotificationCategoriesModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationCategoriesModule") }
}

public final class StubNotificationPermissionsModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationPermissionsModule") }
}

public final class StubNotificationPresenterModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationPresenter") }
}

public final class StubNotificationSchedulerModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationScheduler") }
}

public final class StubNotificationsEmitterModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationsEmitter") }
}

public final class StubNotificationsHandlerModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoNotificationsHandlerModule") }
}

public final class StubPushTokenManagerModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoPushTokenManager") }
}

public final class StubSQLiteModule: Module {
  public func definition() -> ModuleDefinition { Name("ExpoSQLite") }
}

public final class StubServerRegistrationModule: Module {
  public func definition() -> ModuleDefinition { Name("NotificationsServerRegistrationModule") }
}
