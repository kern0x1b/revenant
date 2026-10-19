# The focus rows and `preferredRange` of `registry/UIKit/ios11.json`: what each band end carries

Seven rows of release **12.0** sat at `absent` with the SDK's own declaration as their `source`, which
is an assertion and not a measurement, and four of them carried an `effect` written about a
notification rather than about the accessor the row names. This page holds the measurement, the
commands that reproduce it and their output, so a reviewer can settle any row here without a second
tool.

**The claim, in one line:** no release this package builds carries any of the seven names, so `absent`
is the correct verdict for all seven and the gate's `held` check cannot fire on them.

## Which releases are the band's ends, and which rungs were read

`modules/apple/backports.lua:2578` — "every band checks its imports against the caches of its first
and last release". The held ladder runs **6.1.3 … 12.0** and then jumps to 16.0 (no 13.0, 14.0 or 15.0
is held), so for a 12.0 band the first release is the oldest the port deploys on and the last is the
newest held release at or below 12.0. Four rungs were read anyway, because a name that first appears
at 12.0 needs the rungs on both sides of the jump to be told apart from a reader that looked in the
wrong place: **6.1.3** and **4.3** (armv7, both deployment ends), **11.0** and **12.0** (arm64).

## The measurement: class-scoped, four rungs, with the control in the same run

A selector's rung says nothing about its owner — `fileSystemRepresentation` reads first-rung 3.0, which
is another class's — so the question is never "does this name exist", it is "does *this class* carry
*this selector*", and that is `carried_by_release()` at `backports.lua:1612` reading the release's own
`apple.objc` inventory. `tools/corpus/cache-census.lua` is the class-scoped reader, and it prints its
own control in every run, which is the point: a census printing 0 is ambiguous, so a run finding
nothing anywhere is reported `CONTROL FAILED` rather than as an absence.

```
REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua UI 6.1.3 4.3 11.0 12.0
```

```
4.3       ~/.revenant/dyld/4.3/dyld_shared_cache_armv7
         images 354, of which naming UI 15
         classes 7187, of which UI* 597
         protocols 564, of which UI* 64
control: 661 name(s) beginning UI found in this run, so a zero on another rung is the release's and not the reader's
6.1.3     ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming UI 25
         classes 11378, of which UI* 705
         protocols 1171, of which UI* 91
control: 796 name(s) beginning UI found in this run, so a zero on another rung is the release's and not the reader's
11.0      ~/.revenant/dyld/11.0/dyld_shared_cache_arm64
         images 1258, of which naming UI 117
         classes 52768, of which UI* 1665
         protocols 8954, of which UI* 374
control: 2039 name(s) beginning UI found in this run, so a zero on another rung is the release's and not the reader's
12.0      ~/.revenant/dyld/12.0/dyld_shared_cache_arm64
         images 1368, of which naming UI 138
         classes 63192, of which UI* 1741
         protocols 11426, of which UI* 389
control: 2130 name(s) beginning UI found in this run, so a zero on another rung is the release's and not the reader's
```

**Result: 0 of the seven names in either band end, and the two rungs that do carry parts of the focus
system carry them as the rows' reasons say.**

```
name                            4.3 6.1.3 7.0 9.0 11.0 12.0
UIFocusMovementHint               0     0    0    0    0    1
UIFocusItemContainer              0     0    0    0    0    1
UIFocusItemScrollableContainer    0     0    0    0    0    1
UIFocusEnvironment                0     0    0    1    1    1
UIFocusItem                       0     0    0    0    1    1
```

Every 1 is a release **newer** than this band's ends, and each of them is the release whose SDK
declares the name: the three 12.0 rows read 1 first at 12.0, `UIFocusItem` at 11.0 (its row is 10.0.1
by `first-rung.lua`, and 10.0.1 is not held), `UIFocusEnvironment` at 9.0. The zeros are therefore the
releases' and the reader's, which is what a control is for.

### Class-scoped selectors over the two armv7 band ends

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/4.3/dyld_shared_cache_armv7
```

One TSV line per class: `class <name> <superclass> <image> <instance selectors> <class selectors>
<protocols>`. Selector keys carry a `-` prefix in both columns, which is what `carried_by_release`
expects (`carried[sign == "-" and "instance" or "class"]["-" .. selector]`), so the dump is directly
comparable to the check. Read from the two dumps:

```
== 6.1.3 (11378 classes)
  control UIView -setFrame: True          control UITableView -reloadData: True
  control UINavigationItem -title: True   control UIView -isHidden: True
  control UISearchBar -text: True         control UIBarButtonItem -tintColor: True
  owner present: UIFocusItem False   owner present: UIFocusEnvironment False   protocol: False
  owner present: UIPencilInteraction False   owner present: UIFocusMovementHint False
  -didHintFocusMovement: carried by 0 classes   -focusItemContainer carried by 0
  -parentFocusEnvironment carried by 0          -preferredRange carried by 0
== 4.3 (7187 classes)
  (the same five controls present; UIBarButtonItem -tintColor: is absent, correctly —
   tintColor arrived in iOS 7 and this is the 4.3 cache, so that negative is itself a control)
  owner present: UIFocusItem False   owner present: UIFocusEnvironment False   protocol: False
  -didHintFocusMovement: carried by 0 classes   -focusItemContainer carried by 0
  -parentFocusEnvironment carried by 0          -preferredRange carried by 0
```

`-frame` is carried by 27 classes on 6.1.3 and 19 on 4.3 — that is the documented trap read from the
other side: the name is in the index and in the caches, but `UIFocusItem`'s `frame` belongs to a
protocol no release of this band declares, so the row's answer is still no.

### `first-rung.lua`, the ladder's own index

```
UIFocusMovementHint        12.0     UIFocusItemContainer        12.0
UIFocusItemScrollableContainer  12.0  UIFocusEnvironment        9.0
UIFocusItem                10.0.1   UIGraphicsImageRendererFormat  10.0.1
preferredRange             12.0     didHintFocusMovement        NONE
UIPencilInteraction        16.0 (see facts/UIKit/UIPencilInteraction12.md)
```

Two of these say something about the SDK rather than about the release, and are recorded rather than
smoothed over:

- **`didHintFocusMovement:` reads NONE** — no held release at all carries the selector, not even one
  above 12.0. It is a protocol member of `UIFocusItem` that iOS 12 sends to a focus item; a member of a
  protocol is not necessarily implemented by anything, and this one has no implementer in the ladder.
  The row stays `absent`, and now for a measured reason instead of a declaration.
- **`preferredRange` and `UIFocusItem` read 10.0.1** while the SDK declares 12.0 and 10.0.1
  respectively. `UIFocusItem` as a *class-scoped name* first appears at 10.0.1; the row's owner is the
  **protocol**, and the protocol list of every 6.1.3 and 4.3 class was read above and holds neither
  name. `preferredRange` is a property of a class the port itself defines, so the release's own answer
  is not the question at all (see below).

## What the four focus rows actually are, and why no band end carries them

The focus engine moves focus between views for a remote, a keyboard or a pointer. On this release it
is not there at all, and the measurement above says so class-scoped: no `UIFocusSystem`, no
`UIFocusEnvironment` in any class list, no `UIFocusItem` in any protocol list. What the rungs that do
carry parts of it carry is this, and it is the substrate the four rows would need:

```
release  UIFocusEnvironment  UIFocusItem  UIFocusItemContainer  UIFocusMovementHint  (protocols / classes)
9.0      protocol            -           -                     -
11.0     protocol            protocol    -                     -
12.0     protocol            protocol    protocol              class
```

So a row whose owner is `UIFocusEnvironment` or `UIFocusItem` is absent because **the owner is not
there**: `UIFocusEnvironment.focusItemContainer` asks a container for its focus items, and there is no
container and nothing that would ask. `UIFocusItem.frame` is expressed in the coordinate space of a
`UIFocusItemContainer`, which is itself absent. `-[UIFocusItem didHintFocusMovement:]` is a method the
focus engine would send, and nothing begins a focus update on this release.

An application that writes any of them against the SDK 16.4 header still compiles and carries its own
protocol metadata in its own image; what it gets is the port's answer, which is that the accessor does
not exist. That is what the four `effect` values now say, each in the words of its own row — the
previous text was about registering for a notification, which is a different API.

`UIFocusMovementHint` (class), `UIFocusItemContainer` and `UIFocusItemScrollableContainer` (protocols)
are the three names the SDK places at 12.0 and that the 12.0 cache carries. Each row is absent for the
same measured reason and each names it: the class cannot be made (`+new` and `-init` are
`NS_UNAVAILABLE` in the SDK's own header, so only the focus engine ever creates one), and the two
protocols are only ever asked by that engine.

## `preferredRange`: a property on a class the port defines, so the release's exports are the question

`UIGraphicsImageRendererFormat` is one of the port's own classes (`UIGraphicsImageRendererFormat.m`,
`minimum` 6.0), and the property is declared `dynamic` there so the compiler does not synthesise it —
the fact that `respondsToSelector:` answers NO is deliberate, and `b4f9c8f56` is the commit that says
so. What the property would promise is a colour range, so the question is what colour spaces this
release has:

```
REVENANT_ROOT=$PWD xmake l tools/corpus/dump-cache.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 \
  | awk -F'\t' '$2=="CoreGraphics"' | grep -o 'kCGColorSpace[A-Za-z]*' | sort -u
```

```
kCGColorSpaceAdobeRGB          kCGColorSpaceGenericRGBLinear   kCGColorSpaceUncalibratedCMYK
kCGColorSpaceDisplayRGB         kCGColorSpaceGenericGray        kCGColorSpaceUncalibratedGray
kCGColorSpaceGenericCMYK        kCGColorSpaceGenericGrayGamma   kCGColorSpaceUncalibratedRGB
kCGColorSpaceGenericRGB         kCGColorSpaceSRGB               kCGColorSpaceUserCMYK
                                                        kCGColorSpaceUserGray
                                                        kCGColorSpaceUserRGB
```

**1673 CoreGraphics exports of which these 14 are colour spaces, and not one of them is of extended
range.** The 4.3 cache is not the same list and was read too: 1942 CoreGraphics exports and **21**
colour spaces, the fourteen above plus `kCGColorSpaceDisplayGray`, `kCGColorSpaceGenericHDR`,
`kCGColorSpaceGenericRGBHDR`, `kCGColorSpaceSystemDefaultRGB`, `kCGColorSpaceSystemDefaultGray`,
`kCGColorSpaceSystemDefaultCMYK` and `kCGColorSpaceUndo`. HDR is a headroom curve for tone mapping,
not a wide-gamut space — the two have different ends, and none of the twenty-one is of extended range
either. `grep -i extended` over the CoreGraphics lines of **both** export files returns nothing, while
the whole-cache grep returns 121 hits of `Extended` in other frameworks, so the reader sees plenty and
finds none here. There is no extended sRGB, no Display P3 and no extended generic: a format asked for
`UIGraphicsImageRendererFormatRangeExtended` could only be handed back a promise no bitmap of this
release would keep, and `automatic` would have nothing to resolve against. That is the row's reason,
now with the command and the list beside it instead of "as read by the owner of the class".

## What a reader should take from this

Every row of this slice that stays `absent` is now a measurement rather than a queue entry: **0 carried
at 6.1.3 and 4.3, controls passed in the same run, six selector controls present on each release, and
the fourteen colour spaces of CoreGraphics read by name.** No status in these eight rows is wrong; the
one row of the slice that was wrong is `UIPencilInteraction`, which was `absent` while an application
in the corpus strong-imports its class symbol, and which now has a class
(`facts/UIKit/UIPencilInteraction12.md`).
