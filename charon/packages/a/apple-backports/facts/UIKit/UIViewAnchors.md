# The anchors of a view, iOS 9

Source: the host's own UIKit, asked anchor by anchor, and the differential run of
`tests/backports/host/layout/run.sh`, which builds every constraint both implementations can make from
every anchor and compares them - 4320 constraints and 1800 baseline arrangements, none of them different.

A view answers twelve anchors, and each one is a value that stands for the view and one attribute:

| anchor | class | attribute |
|---|---|---|
| `leadingAnchor`, `trailingAnchor`, `leftAnchor`, `rightAnchor`, `centerXAnchor` | `NSLayoutXAxisAnchor` | Leading, Trailing, Left, Right, CenterX |
| `topAnchor`, `bottomAnchor`, `centerYAnchor`, `firstBaselineAnchor`, `lastBaselineAnchor` | `NSLayoutYAxisAnchor` | Top, Bottom, CenterY, FirstBaseline, LastBaseline |
| `widthAnchor`, `heightAnchor` | `NSLayoutDimension` | Width, Height |

An anchor is made once and kept: the same view answers the same object every time, two views never share
one, and a constraint made from it names that view as its item and that attribute as its attribute. Its
description names the view it belongs to. Nothing else is stored in it - the anchor is the pair, and the
constraint it makes carries the relation, the multiplier, the constant and the priority.

`-viewForFirstBaselineLayout` and `-viewForLastBaselineLayout` answer the view itself. They are the hook a
container overrides so that a baseline constraint against it reaches the view that really draws the text -
`UIStackView` answers its first or last arranged subview - and the differential compares the answer for
every axis and alignment a stack can be arranged in.

## A baseline anchor on a release before iOS 8

The engine of iOS 6 and 7 knows one baseline, `NSLayoutAttributeBaseline` (11), and neither
`FirstBaseline` (12) nor the reading of 11 as the last. So a constraint made from `firstBaselineAnchor` or
`lastBaselineAnchor` there is resolved when it is made: the anchor follows `-viewForFirstBaselineLayout` or
`-viewForLastBaselineLayout` down to the view that answers itself, and if that view shows text - a label, a
text field or a text view - the constraint names it with attribute 11. A view without text has no baseline
of its own; the constraint names it with its top (3) for the first baseline and its bottom (4) for the
last. On iOS 8 and later nothing is resolved and the attributes stay 12 and 11.

This is not read from an address: iOS 6 has no first baseline to read. It is held to today's frames: the
differential lays the same views out once with the system's anchors and once with the backport's resolved
ones - first and last baselines of labels, of plain views and of stacks, 1800 arrangements - and every frame
is the same. On iOS 6 itself the layout test checks that no constraint names an attribute the release does
not know, and lays out a first-baseline row of labels, a plain view and a nested stack against the frames
today's UIKit gives it.
