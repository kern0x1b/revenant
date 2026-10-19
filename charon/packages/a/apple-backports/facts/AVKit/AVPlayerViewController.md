# AVPlayerViewController, iOS 8.0

Rank 25 of `coordination/corpus/band-frameworks.tsv`, `LOAD-FAIL`. `nm -u` of session's `Session` and
`Frameworks/SignalUtilitiesKit.framework/SignalUtilitiesKit` names `_OBJC_CLASS_$_AVPlayerViewController`
without the weak flag, so dyld stops session before its first line on a release without the class.
The selectors session carries for it are `setPlayer:`, `setVideoGravity:` and `setDelegate:`; telegram
sends `requiresLinearPlayback` (`crash-demand-top.tsv`, rank 772). The yattee binary in the corpus
(`yattee/extracted`) does not import the class; the corpus row names it from elsewhere.

The registry used to call the class `absent` because "the class arrived in iOS 8, and nothing in iOS 6
does its work". That is the reason `COORDINATION.md` section 2 forbids, and for a strong-imported class
`absent` means a launch failure, so it is retracted.

## Releases

The armv7 cache ladder (`objc.inventory`, 3.1.3 to 10.3.4) first carries the class and `player`,
`showsPlaybackControls`, `videoGravity`, `readyForDisplay`, `videoBounds`, `contentOverlayView` and
`delegate` at 8.0; `allowsPictureInPicturePlayback`, `pixelBufferAttributes` and
`updatesNowPlayingInfoCenter` at 9.0. The header says 9.0 for `delegate` and 10.0 for
`updatesNowPlayingInfoCenter`; the caches win. `entersFullScreenWhenPlaybackBegins`,
`exitsFullScreenWhenPlaybackEnds` and `requiresLinearPlayback` are after the ladder's last rung, so
their 11.0 is the header's. Every member is in one object, `AVKit/AVPlayerViewController.m`, which
exports only the class, so the class's 8.0 is the object's release; from 8.0 on the band drops it and
the release's own class answers.

## What it is

A `UIViewController` whose view holds, bottom to top: a view with a real `AVPlayerLayer` on the
controller's `player`, `contentOverlayView` (empty, transparent, the application's), and the controls.
Everything is built of what iOS 6 has: `AVPlayerLayer`, `UISlider`, `UIButton` with glyphs drawn with
`UIBezierPath` (iOS 6 has no symbol images), `UIActivityIndicatorView`, `MPNowPlayingInfoCenter`.

- **Controls.** A bottom bar with play/pause, elapsed time, a scrubber, remaining time, and full screen
  when the controller is inline; a top toolbar with the system's own Done item
  (`UIBarButtonSystemItemDone`, so UIKit titles and localizes it) when the controller is presented
  itself or in full screen, and picture in picture when `allowsPictureInPicturePlayback` is `YES`. A tap on the video shows
  or hides them; while playing they hide after three seconds. `showsPlaybackControls = NO` removes them
  and the tap. The scrubber seeks with zero tolerance while dragged, pausing and restoring the rate.
  Play at the end seeks to zero first. A spinner shows while the item's status is unknown or a playing
  item is not likely to keep up; a failed item or player shows its error's description, and keeps
  showing it until another item comes: 6.1.3 takes a failed item out of the player (measured: after a
  file URL that does not exist, `currentItem` is nil and the player's status is `ReadyToPlay`).
- **`videoGravity`** goes to the layer; a value other than the three `AVLayerVideoGravity` values is
  taken as `ResizeAspect`, the default.
- **`readyForDisplay`** is the layer's, and key-value observable through the layer's own notification.
  **`videoBounds`** is computed from the item's `presentationSize`, the gravity and the video view's
  bounds, in the controller's view's coordinates; it is observable for changes of the presentation size
  and the gravity, not of the view's size.
- **`delegate`** (weak) receives the seven picture in picture messages of the 9.0 protocol:
  will/did start, failed to start, will/did stop, should automatically dismiss (default `YES`: a
  presented controller dismisses itself, one in full screen leaves it), and restore user interface
  (not implemented by the delegate: completes with `NO`).
- **Picture in picture** is this package's `AVPictureInPictureController` on the controller's own
  layer: the same layer floats in a window of the application's and comes back to the controller's
  video view when it stops. The controller holds itself while picture in picture is active, so a
  controller that dismissed itself outlives the application's last reference, as the release's does.
- **Full screen** of an inline controller is a modal view controller presented from the topmost
  presented controller of the view's window, cross-dissolving, that takes the controller's content;
  Done brings it back. `entersFullScreenWhenPlaybackBegins` enters it when the player's rate leaves 0
  while the controller is inline and on screen; `exitsFullScreenWhenPlaybackEnds` leaves it at
  `AVPlayerItemDidPlayToEndTimeNotification`, and dismisses a controller presented itself.
- **Done** on a presented controller pauses the player and dismisses the controller. That it pauses
  is reasoned from the release's behaviour, not measured on a release that has the class.
- **`updatesNowPlayingInfoCenter`** (default `YES`) writes `MPNowPlayingInfoCenter`'s `nowPlayingInfo`
  on every change of rate, item, status or duration: the asset's common title once loaded
  (asynchronously), the duration, the elapsed time and the rate. It clears what it wrote when the player
  changes, the property turns off, or the controller goes away.
- **`requiresLinearPlayback`** disables the scrubber.

## What differs from the release, and why

- Picture in picture does not outlive the application leaving the foreground: see
  `facts/AVKit/AVPictureInPictureController.md`. For the same reason
  `canStartPictureInPictureAutomaticallyFromInline` is not carried.
- The interface is this package's, not Apple's: no zoom toggle for the gravity, no volume slider, no
  AirPlay route button, no skip buttons, no subtitle or audio track menu.
- Remote control events (the lock screen's play/pause) are not taken; only the now playing information
  is written.
- The 12.0 full screen messages are sent with the transition coordinator of UIKitBackports, which
  AVKitBackports links: its `presentViewController:` and `dismissViewControllerAnimated:` attach a
  `CharonTransitionCoordinator` to the full screen controller before the transition starts and keep it
  until it ends, so `willBegin...` goes out right after the presentation starts and `willEnd...` right
  after the dismissal starts, each once. The 15.0 full screen restore message is not sent.
- `pixelBufferAttributes` (9.0): 6.1.3's `AVPlayerLayer` takes no pixel format, and its
  `AVPlayerItemVideoOutput` (6.0) does. While attributes are set, an output made with them is on the
  current item (and on each item that becomes current), with IOSurface backing added when the
  attributes do not name it, since the release's CoreImage draws only such a buffer and its own layer
  decodes into them; a display link draws each new buffer through CoreImage into a layer over the player
  layer, with the controller's gravity. The player layer stays, for picture in picture, readiness and
  the video rectangle, and a format CoreImage of the release cannot draw leaves its frames showing,
  said once in the log. Setting nil takes the output and the frames away.
- `showsTimecodes`, `allowsVideoFrameAnalysis`, `speeds`, `selectedSpeed` and `selectSpeed:` are not
  carried and not answered (`@dynamic`, so clang synthesizes no accessor that would store a value and
  do nothing): see the registry's entries.

## On the device

An application on an iPad 2 running 6.1.3, linked against this package (`avkit`), 65 checks, 0
failures (`tests/backports/device/avplayer.m`): it writes a three second 320x240 H.264 file with the
release's `AVAssetWriter` and

- reads the defaults, and that the six members above are not answered while the carried ones are;
- presents the controller modally: `readyForDisplay` turns `YES` and is observed, `videoBounds` is
  `{{0, 214}, {768, 576}}` in a 768x1004 view, the aspect fit of 320x240; Done is shown and full
  screen is not; playback advances; `nowPlayingInfo` carries the duration 3 and the elapsed time;
  `requiresLinearPlayback` disables the scrubber and `showsPlaybackControls = NO` hides the controls;
  Done dismisses and pauses; with the player gone the information is cleared - the center still
  answers the old dictionary right after, and nil within 3 seconds;
- starts picture in picture from the button: will and did start once, the controller dismisses itself
  and outlives the test's last reference, the player layer is in a 160x90 floating window; stopping
  it sends will stop, the restore message (the test's delegate presents the controller again) and did
  stop, the layer is back in the controller's video view, and the controller is released once the
  test lets it go;
- embeds the controller inline: full screen shown and Done not; playing with
  `entersFullScreenWhenPlaybackBegins` presents the full screen controller, which
  `exitsFullScreenWhenPlaybackEnds` leaves at the end of the file, and the content is back inline;
- plays a file that does not exist: the item fails and the controller shows the error and keeps it.

Not seen: no screenshot was taken (the iPad has no screen capture tool), so the look of the controls
is not confirmed by eye; the checks read the views' state.
