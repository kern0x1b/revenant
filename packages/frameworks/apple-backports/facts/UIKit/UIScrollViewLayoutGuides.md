# UIScrollView.frameLayoutGuide and contentLayoutGuide, iOS 11

From iOS 11 a scroll view has two layout guides: `frameLayoutGuide`, the scroll view's frame, which stays where the scroll view is when the content scrolls, and
`contentLayoutGuide`, the origin of the content, whose size the constraints of the content give when an application
constrains its content to it, which then sets `contentSize`. On iOS 6 an application that reads either fails with an unrecognized selector.

Source: the host's own UIKit under Mac Catalyst, recorded by `tests/backports/host/scrollguide/run.sh` (6 records, see
`tests/backports/device/scrollguide-cases.m`) and compared on the iPad 2 and the iPhone 4S by `tests/backports/device/scrollguide.m`.

## What the port does

Each property answers one `UILayoutGuide` per scroll view, owned by the scroll view.

- `frameLayoutGuide` is the size of the scroll view: its width and height are fixed to the size of the bounds and are set again
  when the scroll view's frame changes (record `resized`), and its left and top are at the origin of the content. So a view whose width is the
  guide's width (the usual use: a content view that is as wide as the scroll view) follows the scroll view, as on the host
  (records `frameGuideSize` and `resized`). **What it does not do** is stay where the scroll view is while the content scrolls: the guide is
  at the content's origin, so a view pinned to its top or left edge scrolls away with the content, where the system's stays. An attempt to keep the
  guide's position live (constants for the content offset, or constraints to the scroll view's superview) made the release refuse the layout
  ("Auto Layout still required after executing -layoutSubviews") the first time the offset changed, so it is not done.
- `contentLayoutGuide` has its left and top at the content's origin and no size of its own: a content view that is pinned to its four
  edges and has a size of its own gives it the size. `contentSize` then answers the size of the guide, and the port sets the real
  `contentSize` to it a moment after the layout (one turn of the run loop, since the release refuses a change of the content size inside
  a layout that constraints drive), which is what the system does (record `contentSize`; the record `scrolled` scrolls the content). A guide that nothing
  constrains has no size, as the host's has none, and `contentSize` stays what the application set even though the release's Auto Layout
  would make it empty (record `fromContentSize`).

While a scroll view has either guide the port keeps its content offset across the release's own resets of it when it derives the content
size from constraints (an offset the application, or the user, has set is put back after the release sets the content size).
