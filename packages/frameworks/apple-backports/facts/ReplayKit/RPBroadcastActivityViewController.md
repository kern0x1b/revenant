# RPBroadcastActivityViewController: the broadcast picker, iOS 10 to 11

The view controller an application presents to choose a broadcast service. The release has no ReplayKit and no app
extensions, so there is no service to list. The port answers as the host does for an extension that has nothing to show.

Sources: the `RPBroadcast.h` of the macOS 27.0 SDK (declarations, availability and the deprecation), and a measurement on the
Catalyst host in a windowed app: `tests/backports/host/replaykit-broadcast/` (cases `activity-nil`, `activity-named`).

## What is measured on the host

| question | host answer |
| --- | --- |
| `+loadBroadcastActivityViewControllerWithHandler:` | the handler is called once, before the call returns, on the main thread; the controller is an `RPBroadcastActivityViewController`; the error is nil |
| `+loadBroadcastActivityViewControllerWithPreferredExtension:nil handler:` | the same |
| `+loadBroadcastActivityViewControllerWithPreferredExtension:@"local.revenant.nonexistent" handler:` | the same: a controller and a nil error. The header says the controller is nil when no extension matches; the host does not do that |
| the controller's `view`, loaded | one plain `UIView` with no subviews: no label, no button, no alert |

## What the port answers

The port answers the same: one controller, nil error, the handler called once and before the load returns, and a view that is a
plain `UIView`. The preferred extension is not looked at, because there is no extension to match. The thread the handler runs
on is the caller's: measured on the main thread only, the host's answer for a call from another thread is not measured.

## The differential

`tests/backports/host/replaykit-broadcast/run.sh` compares the two sides per case in separate processes: `activity-nil` and
`activity-named` are EQUAL. A plant that makes the load answer an error turns `activity-nil` red.

## Not measured

- The presentation of the controller in a window: the port's view is a plain view, and the host's presented view was looked at
  only in the probe, which is not part of the commit.
- The host's answer for a call from a thread that is not the main thread.
