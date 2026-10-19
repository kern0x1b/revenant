# NSTextLayoutManager, its fragments and viewport controller, and the TextKit 2 layout delegates, iOS 15 and 16

Introduced in iOS 15.0 and 16.0: the TextKit 2 layout manager, the fragments and line fragments it lays out, the viewport controller that asks
for the part of the document on screen, and the delegates of the layout manager and the viewport. The content side (`NSTextContentStorage`,
`NSTextElementProvider`, the text elements and selections) is built and has its own facts pages (`NSTextContent15.md`, `NSTextRange15.md`).

**Status: owed.** None of the layout rows below is built. The reasons are the measurements in this file.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), measured by `tests/backports/host/textkit2-probe`. That is a host-only run: a
bundled application with a window and the iPad idiom, which prints one line per answer. It has no port side, because there is no port layout
to compare with yet.

## What the host does, measured (2026-10-17)

- **The classes are present:** `NSTextLayoutManager`, `NSTextLayoutFragment`, `NSTextLineFragment` and `NSTextViewportLayoutController`.
- **A plain `UITextView` answers a manager.** `textLayoutManager` is an `NSTextLayoutManager` for a text view made with `initWithFrame:`, which
  is TextKit 2 by default on this release. `+textViewUsingTextLayoutManager:YES` answers the same class.
- **The text container shares the view's manager.** `textContainer.textLayoutManager` is the view's `textLayoutManager`, for a plain view and for
  the factory's view alike.
- **The storage and the viewport.** The manager's content manager is an `NSTextContentStorage`. Its viewport controller is an
  `NSTextViewportLayoutController`, whose delegate is the text view by default.
- **The manager's own delegate is a UIKit controller by default.** A new manager's delegate is the private `_UITextKit2LayoutController`, and
  setting the delegate to an application's object keeps it.
- **Fragments and line fragments.** Two paragraphs `alpha` and `beta` enumerate as two layout fragments, holding two line fragments between them.
- **Two delegate callbacks are called.** The content storage's `textContentStorage:textParagraphWithRange:` is called once while the text lays
  out, and the layout manager's `textLayoutManager:textLayoutFragmentForLocation:inTextElement:` is called twice, once for each of the two fragments.
  Both returned nil in the probe, so the host's default paragraph and fragment were used.
- **The list-marker flag is a flag.** `NSTextContentStorage.includesTextListMarkers` reads NO by default and YES once set.
  **Its effect is not isolated:** the first paragraph's text reads a tab, a bullet, a tab and `a` both before the flag is set and after it, in
  this probe. A different probe is needed before the flag's effect can be stated.

The probe reads the host's answers only. It does not measure what the host's layout does to the pixels, and it does not measure a device.

## What the port does

- The port's text stack is TextKit 1: the `NSLayoutManager` categories (`UIKit/NSLayoutManager+Text7.m`, `+Text12.m`, `+Text13.m`) and the
  text container categories. It has no layout manager of the TextKit 2 kind, no fragments, no line fragments and no viewport controller.
- `UIKit/NSTextContentStorage15.m` carries the content side. Its paragraph call (`charon_paragraph_from:to:`, line 301) asks the storage's
  delegate for a paragraph when the delegate answers the selector, and its element call (line 325) asks the content manager's delegate
  `textContentManager:shouldEnumerateTextElement:options:` the same way. Neither protocol is declared in the port, and no differential measures
  the answers yet.
- The port never calls `textContentManager:textElementAtLocation:` and never calls the layout manager's delegate, the viewport's delegate or
  `textLayoutOrientationAtLocation:`.

## Named gaps

- **No layout.** The port lays text out with TextKit 1. An application that asks for a TextKit 2 manager gets none, or gets a view that answers
  one only if the port builds it. Building a manager that answers the host's fragments would mean a layout engine that produces them, which is
  not on this release.
- **No viewport.** Nothing scrolls a viewport through the port's text, so the viewport controller and its delegate are never asked.
- **Not measured.** `textContentManager:textElementAtLocation:`, the `textLayoutOrientationAtLocation:` of the selection's data source, and the
  behaviour of `includesTextListMarkers` with a probe that isolates it.

## Where this leaves the rows

Every layout row stays `owed`, with its reason corrected to the measurement above. Nothing here is a claim that the port does the layout.
