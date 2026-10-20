# RPPreviewViewController: the preview of a recording, iOS 9 to 11

The view controller that plays a finished recording and offers to save or share it. It is passed to the handler of
`-stopRecordingWithHandler:` on the host. The port's recorder never produces a recording (facts/ReplayKit/RPScreenRecorder.md),
so this slice carries the class and its delegate, and no preview is ever presented.

Sources: the `RPPreviewViewController.h` of the macOS 27.0 SDK (the superclass and the delegate are declared there), and a
measurement on the Catalyst host in a windowed app: `tests/backports/host/replaykit-broadcast/` (case `preview`).

## What is measured on the host

| question | host answer |
| --- | --- |
| a fresh `RPPreviewViewController` | class `RPPreviewViewController`, superclass `UIViewController` |
| `previewControllerDelegate` | nil |
| the view is loaded | NO |

## What the port answers

The same: the class, the superclass `UIViewController`, a nil delegate (a weak property, as the header declares), and a view
that is not loaded until the application asks for it.

## The differential

`tests/backports/host/replaykit-broadcast/run.sh`, case `preview`: EQUAL.

## Not measured

- The presentation of a preview: no recording exists to preview, so the host's presented controller is not looked at.
- The delegate's callbacks (`previewControllerDidFinish:` and the activity-types one): the port never presents a preview, so
  nothing calls them.
