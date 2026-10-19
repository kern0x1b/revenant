# UIWindowScene's geometry request and UISceneWindowingBehaviors, iOS 16.0

Introduced in iOS 16.0: `-[UIWindowScene requestGeometryUpdateWithPreferences:errorHandler:]`, which asks the system to change a scene's
geometry, and `UISceneWindowingBehaviors`, the window controls a scene's own windowing behaviours are made of. The declarations are the SDK
16.4 ones (`UIWindowScene.h`, `UISceneWindowingBehaviors.h`); the class's `-init` and `+new` are unavailable to the compiler.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0.1), measured by `tests/backports/host/window-scene-geometry`, which runs the same
checks in a bundled application with a window and the iPad idiom, once on the host's classes and once on the port's, and compares the two
line for line (14 checks; four planted controls fail).

## As UIKit does

- A request the scene cannot honour is refused with `UISceneErrorDomain` code 101, whose `localizedDescription` is "The current windowing
  mode does not allow for programmatic changes to interface orientation." The handler runs once, before the request returns, on the calling
  thread.
- A nil handler is allowed. The request returns, and nothing is reported.
- `UISceneWindowingBehaviors` made at run time has `closable` and `miniaturizable` both NO, and a set to YES leaves both NO.

## What the port does

- `UIKit/UIWindowScene+Geometry16.m` refuses every request with the same error, delivered synchronously. The port's scene is one fixed window,
  so its windowing mode is the one that does not allow the change.
- `UIKit/UISceneWindowingBehaviors.m`: both flags answer NO, and a set does nothing.

## Named differences

- **The scene's own windowing behaviours.** The host's Mac scene vends a `UISceneWindowingBehaviors`. The port's scene answers nil, as iPhone
  and iPad do (`UIKit/UIWindowScene+Windowing16.m`), so the class is carried for applications that link it, and the scene never hands one out.
  The host-only line, `scene-windowing-behaviors`, is written beside the checks and not compared.
- **The description is the host's key, looked up in the bundle.** The host's refusal reads `UIWindowScene.orientationRequestNotAllowed` from
  UIKit's localization table (`Localizable.loctable` in the Mac UIKitCore bundle, which carries the key in 44 localizations). The release the
  port runs on, iOS 6.1.3, has no windowing scene and so no such key. The port looks the key up in its UIKit bundle and keeps the English as the
  default value, so it answers English there. Measured: under a German locale the host's `NSBundle` lookup of that key still answers English,
  so the German translation is not reached through `NSBundle` on the host, and no German text is claimed.
- **device-unverified.** The port's one fixed windowing mode is the refusing one. A device whose scene allows a resize (iPadOS windowing) has
  not been measured, so on such a device the request is refused here and may be honoured by the release.

## Not built

- `UIWindow.canBecomeKeyWindow` stays owed. A plain window answers YES, and a subclass that answers NO is never made key (a probe run for this
  round, not part of the differential). The port's key-window path does not consult the override, so the property is not yet built.
- `UIWindowSceneActivationInteraction` stays owed; see `UIWindowSceneActivationValues.md`, "Owed: the interaction".
