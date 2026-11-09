# MediaPlayer on iOS 6: the remote command center

`MPRemoteCommandCenter` (iOS 7.1) is what Telegram's `MediaManager.swift:298-300, 658-688` uses for the lock screen and headset
controls. iOS 6.1.3 has none of the classes: on an iPhone 4S each of the 19 classes below resolves to the probe's own image,
not to a system framework. iOS 6 delivers the same controls as `UIEventTypeRemoteControl` events to `UIApplication`, which
`MPRemoteCommandCenter71.m` turns into command events.

## What the backport does

- `+sharedCommandCenter` is one object. Each command property makes its command the first time it is read, under a lock, and
  answers the same object after that. A command starts enabled.
- A target is an object with an action, or a block (`addTargetWithHandler:`, which returns a token for `removeTarget:`). Targets
  are held weakly, so a released one is skipped. A disabled command delivers nothing.
- A command is active when it is enabled and has a target. The first active command calls `-[UIApplication
  beginReceivingRemoteControlEvents]` and the last one to go calls `endReceivingRemoteControlEvents`. The call happens on the
  main queue, so a target can be added from any thread.
- `+load` of a `UIApplication` category exchanges `sendEvent:`. For a remote control event it makes the command event, sets its
  `command` and its `timestamp` (the system uptime at which it was made) and calls the command's targets; then the system's own
  `sendEvent:` runs, so `remoteControlReceivedWithEvent:` still reaches the first responder.

| iOS 6 event subtype | Command | Event class |
| --- | --- | --- |
| play, pause, stop | `playCommand`, `pauseCommand`, `stopCommand` | `MPRemoteCommandEvent` |
| toggle play and pause | `togglePlayPauseCommand` | `MPRemoteCommandEvent` |
| next track, previous track | `nextTrackCommand`, `previousTrackCommand` | `MPRemoteCommandEvent` |
| begin and end seeking forward | `seekForwardCommand` | `MPSeekCommandEvent`, type begin or end |
| begin and end seeking backward | `seekBackwardCommand` | `MPSeekCommandEvent`, type begin or end |

## What iOS 6 never sends

These commands exist, can be enabled, can take targets and keep their values, and no event reaches them, because iOS 6 has no
event for them: `changePlaybackPositionCommand`, `skipForwardCommand` and `skipBackwardCommand` (with `preferredIntervals`),
`ratingCommand` (with its bounds), `likeCommand`, `dislikeCommand` and `bookmarkCommand` (with `active` and the titles),
`changePlaybackRateCommand` (with `supportedPlaybackRates`), `changeRepeatModeCommand` and `changeShuffleModeCommand` (with the
current types), and the two language option commands. Their event classes exist with every property, so an app's handler code
compiles and links. Nothing is faked: no handler of these is ever called, and the status a handler returns is not relayed to
anything, because iOS 6 has no one to tell.

An app that needs a seek bar on the lock screen, or skip buttons, has nothing to hook on iOS 6. Telegram's
`changePlaybackPositionCommand` handler is therefore never called there.

## Why the headers needed work

MediaPlayer marks its declarations with `MP_API(...)`, which is `API_AVAILABLE` under another name, so the lowering did not see
availability on them and the classes stayed iOS 7.1 in the lowered SDK. `region_markers` now reads such wrapper macros from the
SDK headers (see explanation/backports/lowered-implemented-names.md). Telegram's replay then compiles `MediaManager.swift` with
no MediaPlayer error.

## Measured on an iPhone 4S, iOS 6.1.3

`RemoteCommandsProbe` (`tests/device_probe/remote_commands_main.m`), launched through SpringBoard as user `mobile`; 61 checks pass:

- All 19 classes exist and none comes from a system image.
- The storage and identity checks above, and dispatch of every row of the table: each subtype reaches its own command and no
  other, with the right event class and type, and a timestamp between the uptimes before and after the dispatch.
- Several targets, `removeTarget:`, `removeTarget:action:`, the token, a released target, and a disabled command.
- A real command, not a made-up event: `MRMediaRemoteSendCommand` from the private `MediaRemote` framework, sent while the app
  plays a tone and publishes `MPNowPlayingInfoCenter` info, reaches a toggle target and a next track target within 5 seconds, and
  the toggle also reaches the first responder's `remoteControlReceivedWithEvent:` once.

The probe dispatches its made-up events through `-revenant_dispatchRemoteControlEvent:`, the method the exchanged `sendEvent:`
calls first, because the system's own `sendEvent:` crashes on an event that has no `GSEvent` behind it (a segmentation fault at
address 8 in UIKit's own call into GraphicsServices, measured).

Not measured: a headset button or the lock screen buttons, which need a person; seeking events, which no automation here can
make; and a second app that also plays audio.

## Tests

- `tests/lowering_test.lua`: the remote command probe compiled at armv7 iOS 6.0 against the lowered SDK with unguarded
  availability as an error, and the `MP_API` handling of the lowering.
- `RemoteCommandsProbe`, the device probe above (`./xmakew build -P . RemoteCommandsProbe`, installed in `/Applications`, launched
  with `revenant-sblaunch space.kern0x1b.backports.remotecommandsprobe`; the result is `/var/revenant/remote-commands-probe.txt`).
