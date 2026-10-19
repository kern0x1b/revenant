# The system spacing of a layout anchor, iOS 11.0

Introduced in iOS 11.0: a constraint that asks for the spacing the system
considers right between two anchors, rather than a number chosen by hand.

Source: UIKit of the arm64 shared cache of iOS 11.0
(`_UIViewBaselineToBaselineSpacing` at `0x18aa9eda8`) and the differential test
against the host's UIKit (`tests/backports/host/systemspacing`), which compares
the whole shape of the constraint each method returns.

## The constraint the methods return

Whatever the anchors, the answer is an ordinary constraint: the first item and
attribute of the receiver's anchor, the second of the other's, a multiplier of
**one**, a priority of `1000`, inactive, the relation the method's name says,
and the spacing itself in the **constant**, already multiplied by the
multiplier the caller passed. So `multiplier: 3` on a plain pair of edges comes
back as `constant 24`, not as `multiplier 3`.

## What the spacing is

**Between ordinary edges** — leading, trailing, top, bottom, and against an
edge of the container itself — it is **eight points**, and it does not depend on
the fonts of the two views: 17 points over 9 and 9 over 40 both give eight.

**When either anchor is a baseline**, it is computed from the fonts:

    value = lineHeight(lower font) + descender(lower font) - descender(upper font)

rounded **up to the screen scale**: `ceil(value * scale) / scale`. The lower
font is the one belonging to the item of the receiver's anchor, the upper to the
other's. Checked against the host on five pairs: 17/17 gives 20, 9/40 gives 18,
40/9 gives 40.5, 17/40 gives 25, 40/17 gives 42.5. A mixed pair — a baseline on
one side and an edge on the other — uses the same formula.

Two views that carry no font at all fall back to the eight points, even when
both anchors are baselines.

## On iOS 6

The port takes the items and attributes from
`-[NSLayoutAnchor constraintEqualToAnchor:]` of the anchors it is given and adds
only the constant. So on a release before iOS 8, a baseline has the attributes
the anchors give it there, as `facts/UIKit/UIViewAnchors.md` describes in "A
baseline anchor on a release before iOS 8":
- a first baseline of a view that shows text is `NSLayoutAttributeBaseline`
  (11), since `NSLayoutAttributeFirstBaseline` (12) does not exist before iOS 8;
- the baselines of a view that shows none are its top (3) for the first and its
  bottom (4) for the last.

The constant follows the formula above with that release's fonts. On an iPhone
4S running 6.1.3 the system font is `.HelveticaNeueUI`:

| size | line height | descender |
|---|---|---|
| 17 | 21 | -3.91 |
| 40 | 47 | -9.2 |
| 9 | 12 | -2.07 |

The screen scale is 2. The five pairs above therefore give 21, 19.5, 40, 26.5
and 42, where the host's SF gives 20, 18, 40.5, 25 and 42.5. Mixed pairs give
26.5 both ways. Two views without text keep the eight points.

The device run holds every one of these to the formula computed from the
device's own fonts, and to the attributes the device's anchors give. The
comparisons that do not depend on fonts - the edges, the relations, the
multipliers and the container - hold to the host's answers as they are.

## A multiplier below zero asks for nothing

The multiplier scales the spacing, and the current implementation stops at
zero: a multiplier of 0.25 gives a quarter of the spacing, 2 gives twice it, 0
gives none, and **-0.5 or -2 give none either** - not a negative constant.
Measured against the host across both axes; the port floors the constant the
same way. The port first read the multiplication and carried it plainly, which
is where a negative multiplier would have pulled one view over another; the
second pass against the current implementation found it.

## The release that introduced it rounded differently

iOS 11's `_UIViewBaselineToBaselineSpacing` takes the same `value` and rounds it
**up to four points**: `ceil(value / 4) * 4`. That would give 20, 20, 44, 24, 40
for the pairs above, where the current implementation gives 20, 18, 40.5, 25,
42.5. The port follows the **current** implementation, for the reason it follows
current behaviour elsewhere: the application is built against a recent SDK and
gets the current spacing from the system, the difference is small and breaks no
layout, and — decisively — the current formula can be held to the host's own
answers to the last digit, while the older one could only be checked against
itself. Both formulas are written down here so the choice stays visible and
reversible.

## The one case the port does not reproduce

A baseline of a view that shows text, placed under the baseline of a view that
shows none, gets 22 points from UIKit where the port gives the plain eight:
UIKit is measuring something it knows about a view without a font, which the
port cannot read. The host test prints that as a note rather than a failure, so
it stays visible. Every other combination agrees.
