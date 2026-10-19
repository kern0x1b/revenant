# The directional layout margins of a view, iOS 11.0

Introduced in iOS 11.0: the margins of a view named by writing direction rather
than by side.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UIView layoutMargins]` at `0x18a27bca4`) and the differential test against
the host's UIKit through Mac Catalyst (`tests/backports/host/directionalmargins`).

## One set of numbers, two projections

`-layoutMargins` reads `_resolvedInferredLayoutMargins`, and then, if the
margins were set directionally (`_areLayoutMarginsDirectional`) **and** the view
reverses its layout direction (`_shouldReverseLayoutDirection`), answers
`_horizontallyReversedInferredLayoutMargins` instead — the same four numbers
with left and right swapped. So UIKit keeps one set of margins plus a flag
saying which way they were given, and computes the other projection from the
view's direction.

What that means from outside, and what the test holds the port to:

| step | left to right | right to left |
|---|---|---|
| the default | `{8, 8, 8, 8}` both ways | the same |
| `layoutMargins = {1, 2, 3, 4}` | directional `{1, 2, 3, 4}` | directional `{1, 4, 3, 2}` |
| `directionalLayoutMargins = {5, 6, 7, 8}` | plain `{5, 6, 7, 8}` | plain `{5, 8, 7, 6}` |
| then `layoutMargins = {9, 10, 11, 12}` | directional `{9, 10, 11, 12}` | directional `{9, 12, 11, 10}` |

The last row is the one that decides the shape of the port: whichever of the two
was set last wins, and the other is read off it.

## What the port does

It keeps no margins of its own. Setting directional margins writes them through
`-setLayoutMargins:`, mirrored when the view reverses direction, and remembers
both what was set and what was written. Reading them gives back what was set,
but only while `-layoutMargins` still holds exactly what the port wrote: if
anything else has set the plain margins since, the remembered pair is stale and
the answer is read off the plain margins instead. That is how the table above
comes out right without touching `-layoutMargins`, which belongs to the iOS 8
backport.

The direction comes from `-semanticContentAttribute` when the release has it,
and otherwise from `-[UIApplication userInterfaceLayoutDirection]`.

## The one divergence

Changing the direction **after** setting directional margins does not mirror the
plain ones: iOS 11 answers `{5, 8, 7, 6}` where the port still answers
`{5, 6, 7, 8}`. Mirroring on a later change means answering from
`-layoutMargins` itself, which the port does not own.

On iOS 6 the case cannot arise: `-semanticContentAttribute` arrived in iOS 9 and
is not backported, and the application's own direction does not change while it
runs. The test prints the divergence as a note rather than a failure, so it
stays visible.
