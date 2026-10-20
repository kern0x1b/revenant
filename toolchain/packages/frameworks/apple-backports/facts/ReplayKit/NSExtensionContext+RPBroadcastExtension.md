# NSExtensionContext (RPBroadcastExtension): the two calls an extension makes, iOS 10 to 11

The category an extension calls on its `NSExtensionContext` while the user sets up the broadcast. The port carries the iOS
selectors and nothing for macOS, which the header keeps to the Mac.

Sources: the `RPBroadcastExtension.h` of the macOS 27.0 SDK, and a measurement on the Catalyst host in a windowed app:
`tests/backports/host/replaykit-broadcast/` (case `extension-context`).

## What is measured on the host

| question | host answer |
| --- | --- |
| `-loadBroadcastingApplicationInfoWithCompletion:` on a fresh context | the completion is never called on any thread: not within 1 s in the differential, and not within 6 s in an earlier probe of the windowed app (not part of the commit) |
| `-completeRequestWithBroadcastURL:setupInfo:` on a fresh context | returns; no crash, no observable effect |
| `-completeRequestWithBroadcastURL:broadcastConfiguration:setupInfo:` on a fresh context | returns; no crash, no observable effect |

## What the port answers

- `-loadBroadcastingApplicationInfoWithCompletion:` (the iOS signature, with a `UIImage`) never calls its completion. No extension
  is running to give the bundle identifier, the name or the icon.
- `-completeRequestWithBroadcastURL:setupInfo:` returns and does nothing: there is no request to finish.
- `-completeRequestWithBroadcastURL:broadcastConfiguration:setupInfo:`, the iOS 10 to 11 form, returns and does nothing, as its
  sibling does.

## The differential

`tests/backports/host/replaykit-broadcast/run.sh`: `extension-context` is EQUAL.

## Not measured

- The macOS signature of the application-info call: it is the Mac's, and the port does not carry it.
