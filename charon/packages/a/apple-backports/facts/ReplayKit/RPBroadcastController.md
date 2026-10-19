# RPBroadcastController: the controller of a broadcast, iOS 10 to 11

The object an application uses to start, pause, resume and finish a broadcast the user set up. A fresh controller is the only one
the port can give: no session ever exists on this release, so nothing is broadcasting.

Sources: the `RPBroadcast.h` of the macOS 27.0 SDK, and a measurement on the Catalyst host in a windowed app:
`tests/backports/host/replaykit-broadcast/` (case `controller`).

## What is measured on the host

| question | host answer |
| --- | --- |
| a fresh controller: `broadcasting`, `paused` | NO, NO |
| a fresh controller: `broadcastURL`, `serviceInfo`, `delegate`, `broadcastExtensionBundleID` | nil, nil, nil, nil |
| `-pauseBroadcast` and `-resumeBroadcast` on a fresh controller | return, and the state is unchanged |
| `-finishBroadcastWithHandler:` on a fresh controller | the handler is called once, on the main thread, with `RPRecordingErrorDomain` -5829 (`RPRecordingErrorAttemptToStopNonRecording`) |

## What the port answers

- The state is as above: not broadcasting, not paused, and no URL, service information, delegate or extension identifier.
- `pauseBroadcast` and `resumeBroadcast` return and change nothing.
- `finishBroadcastWithHandler:` calls the handler once with -5829. The differential measures this on the main thread, which is where
  the test calls it from.

## Not measured, and the one documented answer

- `-startBroadcastWithHandler:` is NOT measured on the host: a start would begin a capture of the screen, which this work never does.
  The port answers -5808 (`RPRecordingErrorBroadcastInvalidSession`), the code the header documents for a start with no prior
  session, once, on the main queue. The answer is the header's, not the host's. It is the answer the port gives, and the
  differential does not compare it.
- Whether the host's start calls its handler on the main queue or elsewhere is not measured, for the same reason.
