# RPSystemBroadcastPickerView: the button that starts a system broadcast, iOS 12 to 26

A view with a button an application puts on screen to start a broadcast through the system. The release has no ReplayKit, so the
button starts nothing; the port answers as the view answers on the host, which is the view and its properties.

Sources: the `RPBroadcast.h` of the macOS 27.0 SDK, and a measurement on the Catalyst host in a windowed app:
`tests/backports/host/replaykit-broadcast/` (cases `picker`).

## What is measured on the host

| question | host answer |
| --- | --- |
| a fresh picker (`initWithFrame:`): `preferredExtension` | nil |
| a fresh picker: `showsMicrophoneButton` | YES; set to NO, it reads NO |
| the picker's subviews | a `UIButton` with no title; the button holds a `UIImageView` |
| the subviews after `showsMicrophoneButton` is set to NO | the same tree |
| `initWithCoder:` and `encodeWithCoder:` | the picker responds to both |

## What the port answers

- `preferredExtension` is nil on a fresh picker and keeps the value set on it.
- `showsMicrophoneButton` is YES on a fresh picker and keeps the value set on it.
- The view holds the same tree: a custom `UIButton` with no title and a `UIImageView` in it, sized to the view, and the same
  tree after the choice is set to NO.
- `initWithCoder:` builds the same tree, and encoding is the view's own.

## The differential

`tests/backports/host/replaykit-broadcast/run.sh`: `picker` is EQUAL, the tree included. A plant that makes the microphone choice
default to NO turns it red.

## Not measured

- Whether a tap on the button does anything on this release: nothing starts a broadcast here, and a tap on the host would begin
  the system's broadcast flow, so the button's action is not carried.
