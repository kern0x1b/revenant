# RPScreenRecorder: the screen recorder, iOS 9 to 11, as a device that cannot record

The object an application uses to record the app's screen into a movie. This slice carries the recorder's state and its
not-recording answers. It does not record: no movie is written, and `available` answers NO, which the host does not
(ruling 5 of the replaykit3 brief: `available` answers NO until the recorder slice that makes recording work lands, and that
slice turns it YES in the same commit).

Sources: the `RPScreenRecorder.h` of the macOS 27.0 SDK (declarations, availability and the deprecations), and a measurement on
the Catalyst host in a windowed app: `tests/backports/host/replaykit-broadcast/` (cases `recorder` and `recorder-available`).
No case starts a recording or a capture, so the host never records the screen.

## What is measured on the host

| question | host answer |
| --- | --- |
| `+sharedRecorder` | class `RPScreenRecorder`; the same instance on each call |
| `recording`, `microphoneEnabled`, `cameraEnabled` on a fresh recorder | NO, NO, NO |
| `cameraPosition` on a fresh recorder | 1 (`RPCameraPositionFront`) |
| `cameraPreviewView`, `delegate` on a fresh recorder | nil, nil |
| `microphoneEnabled` set to YES, read back | YES |
| `cameraPosition` set to 2 (`RPCameraPositionBack`), read back | 2 |
| `-stopRecordingWithHandler:` when not recording | the handler is called once, before the call returns, on the main thread, with no preview and the error `com.apple.ReplayKit.RPRecordingErrorDomain` / -5829 (`RPRecordingErrorAttemptToStopNonRecording`) |
| `-discardRecordingWithHandler:` when not recording | the handler is never called within 2 s |
| `available` | YES |

## What the port answers

- The singleton, the state and the flags as above: nothing records, the microphone and the camera are NO until set, and the
  microphone and the camera position keep the value the application sets, as the host's do.
- `-stopRecordingWithHandler:` calls the handler once, before it returns, on the calling thread, with no preview and -5829.
- `-discardRecordingWithHandler:` does nothing and never calls its handler.
- `available` answers NO, and logs once that it does so. The host answers YES. This is the one known difference: the differential
  reports it as KNOWN and does not count it. The registry row is `inert`, not `owed`: the gate refuses an `owed` row whose
  selector is built, and a NO is a safe reading while nothing records (an application that checks first starts no recording).
  The recording slice turns it YES in the same commit that makes recording work.
- `cameraPreviewView` is nil: no camera is turned on, so there is no preview to render.

## Not measured

- `cameraEnabled` set to YES is not measured on the host: setting it might bring up the camera, so the case does not set it.
  The port stores the flag as set; the host's readback after a set is not compared.
- The host's answer for a call from a thread that is not the main thread.
- `-startRecordingWithHandler:` and the other start, capture, clip and export selectors: not carried in this slice, so they are
  owed (registry/ReplayKit/recorder.json), and nothing here says what they answer on the host.
