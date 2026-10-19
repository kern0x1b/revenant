# MPRemoteCommandCenter, iOS 7.1

Rank 7 of `coordination/corpus/crash-demand-top.tsv`, `LOAD-FAIL`: a hard, non-weak reference to
this class name kills the process at launch, not merely on first use. Confirmed against
`TelegramUI`'s own tree, 3 of 3 selectors real: `+sharedCommandCenter`,
`changePlaybackPositionCommand`, `nextTrackCommand`, `pauseCommand`, `playCommand`,
`previousTrackCommand`, `togglePlayPauseCommand`.

## What was checked before writing code

`apple.objc.inventory()` against the armv7 shared cache of 6.1.3 confirms none of
`MPRemoteCommandCenter`, `MPRemoteCommand`, `MPRemoteCommandEvent`,
`MPChangePlaybackPositionCommand` or its event exist under any name on this release - a genuine
gap, not a name already claimed by something else. A `grep` of this tree's own `.m` files for
these selectors found no orphaned implementation already carrying one without a registry entry.
This is also the first row this pass needed a new library for: `MediaPlayerBackports` did not
exist (no folder, no `LIBRARIES` entry, no `mediaplayer` config) even though
`registry/MediaPlayer/absent_MediaPlayer.json` already tracked demand against it - added the same
way `CoreSpotlightBackports`/`PushKitBackports` were: a `LIBRARIES` row in
`modules/apple/backports.lua`, a `mediaplayer` config and the matching `links`/install-library
wiring in `packages/a/apple-backports/xmake.lua`.

## What the port does

iOS 6.1.3 has no `MediaPlayer.framework` command surface, but it has the mechanism the new one is
documented to sit above: `UIEventTypeRemoteControl`, delivered to the responder chain with a
`UIEventSubtypeRemoteControl*` subtype since iOS 4.0 - present and real on this release, not
invented. `-[UIApplication sendEvent:]` is swizzled (`+load`, the same interception point
`CharonPushBridge` already uses for PushKit rather than depending on an override the host
application may not implement) to recognize `UIEventTypeRemoteControl`, map its subtype to the
matching `MPRemoteCommand`, build a real `MPRemoteCommandEvent` (or `MPSeekCommandEvent`, with the
correct begin/end `type`, for the two seek commands), and dispatch every registered target/handler
- then still calls through to the release's own `sendEvent:`, so an application's own
`-remoteControlReceivedWithEvent:` override keeps firing exactly as it does today; the two
mechanisms coexist honestly, the way they do on a real, current device.

Real, live mappings: `playCommand` (`UIEventSubtypeRemoteControlPlay`), `pauseCommand` (`...Pause`),
`stopCommand` (`...Stop`), `togglePlayPauseCommand` (`...TogglePlayPause`), `nextTrackCommand`
(`...NextTrack`), `previousTrackCommand` (`...PreviousTrack`), `seekForwardCommand`/
`seekBackwardCommand` (`...BeginSeekingForward`/`EndSeekingForward`/`BeginSeekingBackward`/
`EndSeekingBackward`, with the matching `MPSeekCommandEventType`).

`MPRemoteCommand` itself is carried in full: `-addTarget:action:`, `-removeTarget:action:`,
`-removeTarget:` and `-addTargetWithHandler:` are real target/handler lists this port dispatches
for real, not stored-and-ignored.

## What differs from the release

`changePlaybackPositionCommand`, `ratingCommand`, `likeCommand`/`dislikeCommand`/`bookmarkCommand`,
`skipForwardCommand`/`skipBackwardCommand`, `changePlaybackRateCommand`,
`changeRepeatModeCommand`/`changeShuffleModeCommand` and the two language-option commands are real,
addressable `MPRemoteCommand` (or subclass) objects with real storage for their own extra
properties (`MPFeedbackCommand.active`, `MPRatingCommand.minimumRating`/`maximumRating`, and so on)
- but iOS 6's `UIEventTypeRemoteControl` has no subtype for a scrub, a rating, a like/dislike, a
skip-by-interval, a rate change, a repeat/shuffle-mode change or a language-option change, so none
of them is ever messaged by this port's own bridge. This is the same "carried, never messaged"
contract this port already keeps elsewhere for a property it cannot act on - an application that
sets a handler on `changePlaybackPositionCommand` today gets a real command object back and a
handler that is honestly never called, not a crash and not a fabricated call.

## What is not proven

Not measured on device this pass - the bridge is a `UIApplication` method swizzle and an event
subtype map with no private surface, host-syntax-checked and gate-verified only. What a device pass
would confirm: that a real headset button press or lock-screen control tap actually reaches
`-[UIApplication sendEvent:]` with `UIEventTypeRemoteControl` on 6.1.3 the way the header's own
"available since iOS 4.0" claims, and that `-beginReceivingRemoteControlEvents`/first-responder
status (both still the application's own responsibility, on this release exactly as on a current
one) are enough to receive them without any additional accommodation this port would need to make.

## Releases, measured on the cache ladder

`apple.objc.inventory()` over every armv7 cache from 7.0 to 10.3.4 (a nonsense selector and a
nonsense class as negative controls): `MPRemoteCommandCenter` and its command properties from
`playCommand` to `changePlaybackRateCommand` first appear at 7.1.2, the first 7.1 cache on the ladder
(no 7.1 or 7.1.1 cache is held), so their rows carry 7.1.2, not the header's 7.1.
`-changePlaybackPositionCommand`, `-changeRepeatModeCommand`, `-changeShuffleModeCommand` and
`MPChangePlaybackPositionCommandEvent` first appear at 8.0; the language option commands and
`MPChangeLanguageOptionCommandEvent` at 9.0; the class `MPChangePlaybackPositionCommand` only at
9.2.1. What the release's own `-changePlaybackPositionCommand` answers between 8.0 and 9.2 is not
measured.
