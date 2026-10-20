# The adjusted content inset of a scroll view, iOS 11.0

Introduced in iOS 11.0: the content inset a scroll view really lays out by,
once the safe area is folded into it.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`-[UIScrollView adjustedContentInset]` at `0x18a2a8320`,
`-_edgesApplyingSafeAreaInsetsToContentInset` at `0x18a2a97f0`,
`-_contentScrollsAlongXAxis` at `0x18a2aa180`), read in full. There is no host
differential for this one either: a scroll view outside a window has no safe
area to fold in, so the expectations of the device test come from the algorithm
below.

## Which edges of the safe area are folded in

`-_edgesApplyingSafeAreaInsetsToContentInset` answers a mask of edges, and the
answer depends on the behaviour and on whether the content scrolls:

| behaviour | edges |
|---|---|
| `Never` | none |
| `Always` | all four |
| `Automatic`, `ScrollableAxes` | see below |

For the two automatic behaviours:

1. the horizontal edges are taken when the content is wider than the frame or
   `-_contentScrollsAlongXAxis` says it scrolls that way; otherwise only the
   top and bottom are kept;
2. the vertical edges are dropped again — in the code literally
   `edges &= Left|Right` — when the content is no taller than the frame and
   `-_contentScrollsAlongYAxis` says it does not scroll that way;
3. finally, when the behaviour is `Automatic` **and** UIKit has marked the
   scroll view as the content scroll view of a controller
   (`-_applyVerticalSafeAreaInsetsToNonscrollingContent`), the top and bottom
   are added back.

`-_contentScrollsAlongXAxis` reads a three-valued flag: set by UIKit, or, when
unset, decided from the content size against the frame.

`adjustedContentInset` is then the content inset plus the safe area on the
edges that survived, edge by edge.

## The one part that does not reach iOS 6

Step 3 rests on a mark UIKit puts on the controller's content scroll view.
iOS 6 has no such mark and no such notion, so for the port that flag is always
off: `Automatic` and `ScrollableAxes` behave the same way. Everything else
carries over exactly, including that bouncing counts as scrolling, which is how
the port reads `-_contentScrollsAlong*Axis` without the flag: the content is
larger than the frame on that axis, or the scroll view always bounces on it.

Like the safe area itself, Apple keeps the adjusted inset in a field (offset
`0x5d0`) and refreshes it during layout; the port computes it on every read,
for the same reason and with the same result.

`-adjustedContentInsetDidChange` and `-[UIScrollViewDelegate scrollViewDidChangeAdjustedContentInset:]`
are not declared: both are called from the moment the value changes, which the
port never sees without replacing UIKit's layout.

## How far this is checked

On an iPhone 4S (6.1.3, armv7), inside the same tweak as the safe area:
never adjusting leaves the content inset alone, always adjusting adds the whole
safe area, content that does not scroll gets nothing, content taller than the
frame takes the vertical edges, bouncing vertically counts as scrolling,
content larger both ways takes all four edges, and a content inset of the
application's own adds to the safe area edge by edge. All of them agreed, in a
run of forty-one checks with no failures.
