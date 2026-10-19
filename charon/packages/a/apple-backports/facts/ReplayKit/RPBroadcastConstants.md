# RPBroadcastConstants: the keys, the error domain and the codes of the broadcast family, iOS 9 to 11

ReplayKit arrived in iOS 9 and the release (6.1.3) has no ReplayKit framework. The library carries the constants an application
compares against, and the codes the broadcast family answers with, so a value that is compared with NSError or a dictionary key
is the one the host has.

Sources: the ReplayKit headers of the macOS 27.0 SDK (`RPBroadcast.h`, `RPError.h`, `RPBroadcastConfiguration.h`), read at run
time from the host: each string constant was read as its value on the Catalyst host, in `tests/backports/host/replaykit-broadcast/`
(case `constants`, which prints the values and the codes).

## What is measured on the host

| name | value |
| --- | --- |
| `RPApplicationInfoBundleIdentifierKey` | `"RPApplicationInfoBundleIdentifier"` |
| `RPVideoSampleOrientationKey` | `"RPSampleBufferVideoOrientation"` |
| `RPRecordingErrorDomain` | `"com.apple.ReplayKit.RPRecordingErrorDomain"` |
| `RPRecordingErrorUnknown` | -5800 |
| `RPRecordingErrorUserDeclined` | -5801 |
| `RPRecordingErrorInterrupted` | -5806 |
| `RPRecordingErrorBroadcastInvalidSession` | -5808 (header; see RPBroadcastController.md) |
| `RPRecordingErrorAttemptToStopNonRecording` | -5829 |
| `RPSampleBufferTypeVideo`, `RPSampleBufferTypeAudioApp`, `RPSampleBufferTypeAudioMic` | 1, 2, 3 |

The codes are the header's values in `RPError.h`, and the host prints the same numbers.

## What the port answers

The port defines the three string constants with the values above, and the error domain is the one every broadcast error is
made in. The codes are the header's enumeration, which the port compiles against. The values are not computed in the port.

## The differential

Case `constants` prints the three strings and the codes on both sides; the two outputs are equal.

## Not measured

- The value of `RPRecordingErrorDomain` on a device: the device has no ReplayKit, so no error in that domain is ever made there.
