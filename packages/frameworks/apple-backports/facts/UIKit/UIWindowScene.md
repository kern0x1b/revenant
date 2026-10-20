# UIWindowScene.activityItemsConfigurationSource, iOS 15

Introduced in iOS 15.0: the object that supplies the activity items configuration for the scene's sharing and activities. The property is
nullable and weak, as the header says: the scene does not keep the provider alive. When it answers nil, the release uses the
`activityItemsConfiguration` of the most-presented view controller of the scene's key window.

Source: the host's own UIKit under Mac Catalyst, measured in a bundled application by `tests/backports/host/window-scene-activity` (9 checks;
the host's window scene and the port's `UIWindowScene`, printed side by side, must match line for line; three planted controls fail).

## What the port does

- The property is nil until set, and answers the object given, the same object, for as long as the object lives.
- The property is weak. A provider dropped by the application reads back nil, as the host's does.
- Setting nil clears it.
- The port does not supply the configuration to the sharing sheets of the system, so the provider is held and answered, and never asked.
  The fallback to the most-presented view controller's configuration is the release's and is not reproduced.
