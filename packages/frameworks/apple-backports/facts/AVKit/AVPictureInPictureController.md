# AVPictureInPictureController, iOS 9.0

Rank 18 of `coordination/corpus/crash-demand-top.tsv`, `LOAD-FAIL`, `class_confirmed` against both
`telegram` and `yattee`'s own trees. Five of telegram's own submodules confirm this is real
picture-in-picture used in calls, not merely an availability check the corpus can't otherwise
distinguish from a stub.

## What was checked before writing code

`apple.objc.inventory()` against the armv7 shared cache of 6.1.3 found neither
`AVPictureInPictureController` nor `AVPictureInPictureControllerDelegate` under any name - a
genuine gap. `AVPlayerLayer`, the real class `-initWithPlayerLayer:` takes, is already real and
exported on this release. Ladder-walked to 9.0, matching the SDK header's own attribute this time
(not every class drifts the way `MPRemoteCommandCenter`'s did). A `grep` of this tree's own `.m`
files found no orphaned implementation.

## The wall, measured, not assumed

`AVKit.framework` does not exist at all on this release - not a framework carrying older API
around one missing class, the way `MediaPlayer.framework` does. More fundamentally, no cross-app
window-compositing surface exists anywhere in this tree for a third-party dylib to draw into: the
real system feature floats a window SpringBoard itself owns and composites above every running
app. This is the same wall `CoreSpotlightBackports`' own search bundle hit trying to reach the
system search UI (`-appendResults:` blocks on connection state an out-of-process bundle cannot
reach) - a genuine, measured stop, not a guess. `CallKitBackports`' `RevenantCallScreen` answers the
same kind of wall for its own call screen by shipping only the application's half of a two-process
design (Darwin notifications plus a shared file) and naming the other half - a SpringBoard-side
tweak - as something this tree does not currently build. No such companion exists for
picture-in-picture either.

So: this port cannot make the video survive the host app losing focus. That is out of reach
without a SpringBoard-side component, and is not attempted here.

## What is real and in reach

Everything picture-in-picture does *while the host app stays in the foreground* - which is what a
call screen actually needs, and precisely what telegram's five confirming submodules use it for.
`-startPictureInPicture` reparents the caller's real `AVPlayerLayer` - the same `CALayer`, still
attached to the same `AVPlayer`, still decoding and rendering real frames - into a small
(160x90pt) floating `UIWindow` at `UIWindowLevelAlert - 1` (above the host app's own content,
below system alerts), draggable anywhere on screen via a real `UIPanGestureRecognizer` clamped to
the screen bounds, with a double-tap to close. `-stopPictureInPicture` reparents the same layer
back into its original superlayer, at its original frame and sublayer index, and dismisses the
window - the original layout is restored exactly, not approximated.

The real will/did-start and will/did-stop delegate callbacks fire around both transitions, and
`-startPictureInPicture` fires the real `failedToStartPictureInPictureWithError:` callback instead
if the player layer has no superlayer to reparent from or is not yet ready for display -
`AVKitErrorDomain` is referenced as a literal string, not the real exported constant (which this
release does not carry and this port does not otherwise need).

`+isPictureInPictureSupported` answers unconditionally `YES`: unlike the system feature this
substitutes for, an in-app floating window needs no hardware entitlement or background-video
capability - it works identically on every device this release runs on.

## What differs from the release, honestly

- Picture-in-picture does not outlive the host app leaving the foreground - see "the wall,
  measured, not assumed" above. A caller backgrounding the app while picture-in-picture is active
  will simply have its window suspended with the rest of the app, the same as any other UI.
- `-pictureInPicturePossible` is computed fresh from the real `AVPlayerLayer.readyForDisplay` and
  `.player` on every access - real state, not a fixed default - but it is **not** KVO-observable
  the way Apple's own property is documented to be: nothing in this port drives an automatic KVO
  notification when `readyForDisplay` changes underneath it. A caller that reads the property
  directly gets the true answer every time; a caller that key-value-observes it for automatic UI
  updates (e.g. enabling a PiP button) will not see one fire.

## What is not proven

Not measured on device this pass - the floating window, the drag gesture, and the layer
reparenting are host-syntax-checked and gate-verified only. A device pass would confirm: that
reparenting a live `AVPlayerLayer` between an app's own view hierarchy and a separate `UIWindow`
does not glitch or drop frames during the `CATransaction`-wrapped move; that
`UIWindowLevelAlert - 1` in fact keeps the floating window above the host app's content without
also covering system alerts it should not (both expected from the documented window-level
ordering, but not exercised); and that a real call screen's `AVPlayerLayer` (video already
decoding live camera/remote frames) reparents cleanly under real memory and thermal pressure, not
just a static test asset.

## Properties the header declares beside these

Until 2026-09-23 clang synthesized, without a word, an accessor for every property of the header the
class did not write itself (`nm` of the object: `contentSource`, `canStartPictureInPictureAutomaticallyFromInline`,
`canStopPictureInPicture`, `requiresLinearPlayback`, `isPictureInPictureSuspended`), so the class
answered them by storing a value it never used. Now:

- `requiresLinearPlayback` (14.0) is stored and answered: the floating window has no seek control,
  so playback in it is linear whatever the value.
- `pictureInPictureSuspended` answers `NO`: the window is never suspended while the application runs.
- `contentSource` and `-initWithContentSource:` (15.0) and
  `canStartPictureInPictureAutomaticallyFromInline` (14.2) are `@dynamic` and not answered - the
  first two need `AVPictureInPictureControllerContentSource`, which is not carried, the third starts
  picture in picture as the application leaves the foreground, which the window does not survive.
- `canStopPictureInPicture` is tvOS's and is not answered on iOS.

## AVKitErrorDomain, and the -1001

Two values in this file's error path were wrong or unmeasured, and both are now read rather than
assumed. `facts/AVKit/Absent.md` carries the full measurement with the commands; the short form:

The port reported its picture-in-picture start failure as code **-1000** with the domain written as a
literal. `AVError.h:30` names -1000 `AVKitErrorUnknown`, which is what the framework answers when it
does not know which error it is - and this port does know: `AVError.h:31` gives
`AVKitErrorPictureInPictureStartFailed` as **-1001**, and a failure to start picture in picture is that
error. The code is -1001 now.

The domain literal became the real constant. The queue header's rule is that the name is never the
value, so the value was read out of Apple's own data rather than copied off the name:

```
$ printf 'AVKitErrorDomain\tp\tp\ts\n' > .agent-work/runs/avkit9-symbols.tsv
$ REVENANT_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.revenant/dyld/9.0/dyld_shared_cache_armv7 .agent-work/runs/avkit9-symbols.tsv
```

against the armv7 shared cache of 9.0, which answers the text `AVKitErrorDomain`. The
name and the value do coincide; that is now a reading and not a hope. `AVKitErrorDomain` is declared in
this file's object - it is the 9.0 object, which is the release the constant is from - and the row moved
out of `absent_AVKit.json` into `ios9picture.json` as `implemented`, because a row that a class object
exports is not absent however the release treats it.
