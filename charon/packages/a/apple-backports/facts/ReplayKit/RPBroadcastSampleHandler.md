# RPBroadcastSampleHandler, RPBroadcastHandler and RPBroadcastMP4ClipHandler: the extension's handlers, iOS 10 to 11

The classes an extension subclasses to receive the frames of a broadcast. They are made by the system, in an extension process
this release does not run, so no sample or clip ever reaches the port's handler. The port carries the classes an application
subclasses, and each method answers as the host's base class does.

Sources: the `RPBroadcast.h` and `RPBroadcastExtension.h` of the macOS 27.0 SDK, and a measurement on the Catalyst host in a windowed
app: `tests/backports/host/replaykit-broadcast/` (cases `superclasses`, `handler-calls`, `clip-handler`, `request-context`).

## What is measured on the host

| question | host answer |
| --- | --- |
| superclasses | `RPBroadcastSampleHandler` -> `RPBroadcastHandler` -> `NSObject`; `RPBroadcastMP4ClipHandler` -> `RPBroadcastHandler` |
| `RPBroadcastSampleHandler` lifecycle and sample calls (`broadcastStartedWithSetupInfo:`, `broadcastPaused`, `broadcastResumed`, `updateServiceInfo:`, `broadcastFinished`, `updateBroadcastURL:`, `broadcastAnnotatedWithApplicationInfo:`, `processSampleBuffer:withType:`, `finishBroadcastWithError:`) | each returns; no crash, no observable effect (the base class holds no readable state) |
| `RPBroadcastMP4ClipHandler` `processMP4ClipWithURL:setupInfo:finished:` and `finishedProcessingMP4ClipWithUpdatedBroadcastConfiguration:error:` | each returns; no crash |
| `-beginRequestWithExtensionContext:` with a fresh `NSExtensionContext` | host crash: NSInvalidArgumentException, `-[NSExtensionContext setDelegate:]` unrecognized (exit 134), inside ReplayKit's base method |

## What the port answers

- The superclasses are the host's.
- Every lifecycle and sample call returns and does nothing. The base handler keeps the extension context it is given and calls nothing
  on it. The host crashes on a fresh context, and this release has no app extension to make the call that would follow, so the
  port stores the context and does not call its delegate. The context is stored for the request's life and no more; nothing outside
  the handler can see it.
- The clip handler's two calls return and do nothing: no clip is recorded on this release.

## The differential

`tests/backports/host/replaykit-broadcast/run.sh`: `superclasses`, `handler-calls` and `clip-handler` are EQUAL. `request-context` is
named as a host crash and is not compared; the port returns from it.

## Not measured

- Whether the host's `-beginRequestWithExtensionContext:` is declared on `RPBroadcastSampleHandler` or inherited: the port declares it
  on `RPBroadcastHandler`, and the host's crash is recorded under the sample handler's name, which is where it was called.
- Any effect of the lifecycle calls on the host, beyond returning: the host's base class has no readable state.
