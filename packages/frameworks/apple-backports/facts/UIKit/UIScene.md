# UIScene and UIWindowScene, iOS 13

Introduced in iOS 13: an application is one or more scenes, each with a session, a delegate and a window scene that holds its
windows, and the application delegate stops being the place the interface is built. iOS 6 has one application and one
window stack, so the port carries the whole scene surface as a facade over that: one implicit scene, one session, and the
windows the application already has.

Source: the SDK headers for the surface, and the behaviour the documentation gives for the launch sequence; the constants
are compared against the host's own UIKit in `tests/backports/host/uikit2` (scenes). The shared caches of iOS 6.0 and 7.0 have
no scene class. The order of the delegate call and the notification of a lifecycle step is not measured on a release with
scenes; the port sends the delegate call first.

## What the port does

- `UIApplication.connectedScenes` is the set of the one scene, `openSessions` the set of its session, and
  `supportsMultipleScenes` is NO. The scene is a `UIWindowScene` of the configuration's scene class, and its session's
  configuration comes from `UIApplicationSceneManifest` of the Info.plist (`UISceneConfigurations` of the application
  role: `UISceneConfigurationName`, `UISceneClassName`, `UISceneDelegateClassName`, `UISceneStoryboardFile`), or from
  `-application:configurationForConnectingSceneSession:options:` of the application delegate, which is asked first and
  wins. An application with no manifest still has the scene, with no delegate.
- After `-application:didFinishLaunchingWithOptions:` returns, the scene delegate class is instantiated and, when the
  configuration names a storyboard, a window with its initial controller is made and handed to the delegate's `window`;
  then `-scene:willConnectToSession:options:` is sent with the connection options, which carry the launch URL as a URL
  context and the source application. The scene is then in the background state and, since iOS 6 launches in front, is
  moved to foreground inactive with `-sceneWillEnterForeground:`.
- The application's own notifications move the scene from then on: becoming active sends `-sceneDidBecomeActive:`,
  resigning `-sceneWillResignActive:`, entering the background `-sceneDidEnterBackground:` and coming back
  `-sceneWillEnterForeground:`, each followed by the scene notification (`UISceneWillConnectNotification`,
  `UISceneDidActivateNotification`, `UISceneWillDeactivateNotification`, `UISceneWillEnterForegroundNotification`,
  `UISceneDidEnterBackgroundNotification`) with the scene as the object. `activationState` follows.
- A URL opened while the application runs reaches `-scene:openURLContexts:` when the scene delegate has it, with a context
  of the URL, the source application and the annotation; otherwise the application delegate's own method answers as
  before. The URL the application was launched with is delivered in the connection options only, not a second time.
- `-[UIWindow initWithWindowScene:]` makes a window the size of the screen and `UIWindow.windowScene` answers the scene a
  window was given, or the one scene. `UIWindowScene` answers the main screen, the interface orientation of the
  application, the application's windows, the trait collection of the screen, a coordinate space of the screen that turns
  with the interface orientation and converts through the window space, `isFullScreen` YES, no size restrictions, and a
  status bar manager that reads the application's status bar style, visibility and frame.
- `-windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:` of a window scene delegate is sent when
  the application's interface orientation changes.
- `-[UIScene openURL:options:completionHandler:]` opens the URL with the application and answers whether it did; with
  `universalLinksOnly` it answers NO, as iOS 6 has no universal links. The value classes - configuration, session,
  connection options, URL context and options, activation conditions, size restrictions, request options - hold what
  they are given, with the defaults of the header.

## What it cannot do

- There is one scene. `requestSceneSessionActivation:userActivity:options:errorHandler:` answers with
  `UISceneErrorDomain` code 0 (multiple scenes not supported) unless it names the one session, and
  `requestSceneSessionDestruction:options:errorHandler:` with code 1 (denied); `requestSceneSessionRefresh:` does nothing.
- The application delegate still hears `applicationDidBecomeActive:` and its siblings; the release with scenes stops
  sending them once a scene delegate is there.
- `sceneDidDisconnect:` is never sent, as the one scene lives as long as the application. Handoff, shortcut items, CloudKit
  shares and the notification response of the connection options are not carried: the options answer nil or an empty set
  for them, and the delegate methods that would receive them are never sent.
## The external display role's value

`UIWindowSceneSessionRoleExternalDisplay` holds `@"UIWindowSceneSessionRoleExternalDisplayNonInteractive"`, the same
string as `UIWindowSceneSessionRoleExternalDisplayNonInteractive` (iOS 16), which the header deprecates it in favour
of. That is what the host's UIKit answers for both constants (`scenes_test.m` holds the port to it), and a round of
2026-09-23 that gave the constant its own name as its value, on the reading that every other role holds a literal
identical to its name, had nothing to measure that against and was wrong for the host. What the value was in iOS 13 to 15
is not measured: no runtime of those releases is on the host. The port answers as the host does.
`UIWindowSceneSessionRoleExternalDisplayNonInteractive` is defined in its own right in `UISceneConstants16.m` - a separate
object file from `UISceneConstants.m`'s iOS 13.0 constants, since `check_registry` requires one release per object file.

- State restoration by activity is carried. When the application enters the background and when it terminates, the scene
  delegate is asked `stateRestorationActivityForScene:`; the activity (type, title, user info, web page URL, required keys,
  expiration date and keywords) is archived in the application's user defaults under the session identifier, and an answer
  of nil removes what was kept. On the next launch the session's `stateRestorationActivity` is that activity before
  `scene:willConnectToSession:options:` is sent, and `scene:restoreInteractionStateWithUserActivity:` follows it. The
  archive requires secure coding, as the release's own does, and is read back naming the property list classes an
  activity's user info is documented to hold - dictionary, array, set, string, number, date, data, URL, UUID and null. A
  user info that holds anything else does not archive and nothing is kept for that launch; a value that comes back as the
  wrong kind is dropped rather than assigned. The session's `stateRestorationActivity` is not archived with the session
  itself, which keeps only its role, configuration and persistent identifier.

## `UISceneErrorDomain`, iOS 15

`UIKit/UISceneConstants15.m` exports `UISceneErrorDomain` with the value `@"UISceneErrorDomain"`, the literal the port's
scene requests already built their errors with (`revenant_scene_error` in `UIKit/UIApplication+Scenes.m`, which now uses the
constant, so the two cannot drift). Before, the domain was right and the constant absent: an application comparing
`error.domain` against `UISceneErrorDomain` read a NULL weak reference and never matched. `introduced` is the header's 15.0,
**not measured**: the cache ladder has 12.0 and then 16.0, no 13-15 rung to place the first export between them. The value
is the port's own literal, and it is the system's: UIKitCore of the 16.0 cache exports `UISceneErrorDomain` as `@"UISceneErrorDomain"`
(`tools/corpus/cache-value.lua` on the 16.0 cache).
`tools/release-split.lua` over the built objects reports `_UISceneErrorDomain` first exported in **no** release, but that
says nothing: the iOS 13 scene notifications of `UISceneConstants.o` read `none` the same way, and across all 713 symbols it
finds no first export above 10.0.1, so the tool does not see UIKit's exports on the 12.0-18.0 rungs.

## `UIWindowScene.keyWindow`, iOS 15

`UIKit/UIWindowScene+KeyWindow15.m` answers the application's key window when it is one of the scene's windows, and nil when there is
no key window. The release has one scene and the port's scene answers the application's windows as its own (`UIKit/UIWindowScene.m`),
so in practice it is `[UIApplication sharedApplication].keyWindow`. Ladder by `objc.inventory`
(`.agent-work/plan-and-analysis/b1314-flips/ladder-leaf-anchor-key.log`): `UIWindowScene` is not in the 12.0 cache, and `keyWindow` is in
16.0 and 18.0 with `windows` as the positive control; no 13-15 cache, so `introduced` stays the header's 15.0. Not run on a device: a process has no application (the last section).

## `UIWindowScene.windowingBehaviors`, iOS 16

`UIKit/UIWindowScene+Windowing16.m` answers nil. The header: "This property will be nil on unsupported platforms, otherwise will
provide a mutable object for window behavior customization"; the behaviours are closing and miniaturizing a window, which a phone or
tablet does not have, and `UISceneWindowingBehaviors` itself stays absent, since nothing ever hands one out. `objc.inventory`
(`ladder-rest.log`): the getter is not in 12.0 (nor the class) and is in 16.0 and 18.0; no 13-15 cache, so `introduced` stays the
header's 16.0. That the system answers nil on an iPhone is the header's word, not measured.

## `UIScene.subtitle`, iOS 15

Measured in a bundled Mac Catalyst app (`tests/backports/host/scene-subtitle`), because the host's setter reaches the shared application
delegate and a bare process has none. The app's scene delegate runs the same checks on the host's scene and on the port's `UIScene`, and the
two outputs must match: 10 checks.

- A scene that was never given a subtitle answers nil.
- The subtitle is kept as the object given, not copied, although the header says `copy`: a string changed after it was set shows through.
- Setting nil stores the empty string, which the scene answers from then on. The empty string itself is kept.
- The title is the empty string until it is set (the port answers the same).

The port keeps the subtitle by reference and turns nil into the empty string, as the host does. Controls that copy the subtitle, or keep nil,
each fail the differential.

## Value classes' storage, iOS 13 to 15

- `UISceneOpenURLOptions.eventAttribution` (iOS 14.5) is read-only and nil, as the host answers it for a value that has none.
- `UISceneOpenExternalURLOptions.eventAttribution` (iOS 14.5) is nil by default. The attribution is **copied** on set, so a change to
  the object given after the set does not reach it; nil clears it.
- `UISceneActivationRequestOptions.collectionJoinBehavior` is 0 by default and keeps the integer it is given. It has no registry row, and
  the port carries it as UIKit does.

Measured by `tests/backports/host/storage-config`: the port and the host print the same values for each.

## On a device, iOS 6.1.3

On an iPad 2 of iOS 6.1.3 (2026-09-23), a process of the band's own (`.agent-work/runs/b1314-live/main.m`, output `run4-all.txt` beside it) loaded the gate's `libUIKitBackports.dylib` and checked `UISceneErrorDomain` read through the library's export. `keyWindow` and `windowingBehaviors` were not run: a process has no application and no scene.
