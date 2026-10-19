# The 16.0 rows of `registry/UIKit/ios15-16.json`: what each band end carries

115 rows of release **16.0** sat at `absent` with the SDK's own declaration as their only `source`,
which is an assertion and not a measurement. This page holds the measurement, the commands that
reproduce it, and their output, so a reviewer can settle any row here without a second tool.

**The claim, in one line:** no held release the 16.0 band builds carries any of the 115 names, so
`absent` is the correct verdict for all 115 and the gate's `held` check cannot fire on this file.

## Which releases are the band's ends, and why these two

`modules/apple/backports.lua:2578` — "every band checks its imports against the caches of its first
and last release". The held ladder (`dyld.held_ladder`) jumps **12.0 -> 16.0**: no 13.0, 14.0 or 15.0
is held. So for a band whose points end at 16.0 the first release is the oldest the port deploys on,
**6.1.3**, and the last is the newest held release below 16.0, **12.0**. Those two are this file's
band ends, and a row that survives both cannot fire `held`.

## The measurement: class-scoped, both ends, with the control in the same run

The rule that makes a selector's rung useless here: **a selector's rung says nothing about its owner**
(`fileSystemRepresentation` reads 3.0 — another class's — while `-[NSURL fileSystemRepresentation]`
is 7.0). So the question is never "does this name exist", it is "does *this class* carry *this
selector*", and that is `carried_by_release()` at `backports.lua:1612-1631` reading the release's own
`apple.objc` inventory.

```
REVENANT_ROOT=$PWD xmake l tools/corpus/cache-census.lua UI 6.1.3 12.0
```

Output, abridged to its control line and the two headers (the full run is 2926 names):

```
6.1.3     ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7
         images 524, of which naming UI 25
         classes 11378, of which UI* 705 (UIActionSheet UIAlertView ... UIBarButtonItem UIButton UICollectionViewCell ...)
         protocols 1171, of which UI* 91 (UIAccessibilityElement UIActionSheetDelegate ... UITableViewDelegate UITextViewDelegate ...)
12.0      ~/.revenant/dyld/12.0/dyld_shared_cache_arm64
         images 1368, of which naming UI 138
         classes 63192, of which UI* 1741 (...)
         protocols 11426, of which UI* 389 (...)
control: 2926 name(s) beginning UI found in this run, so a zero on another rung is the release's and not the reader's
```

**The control is the point of that run.** A census printing 0 is ambiguous — the name may be absent,
or the reader may be looking at the wrong thing — so each release prints its image, class and
protocol counts, and a run finding nothing anywhere is reported `CONTROL FAILED`. 2926 names found
means the reader was looking at the right thing.

**Result: 0 of the 115 names appear in either band end.**

The census answers the 29 class and protocol rows, because a class name belongs to exactly one class
and first-rung is therefore a *class-scoped* answer for them — which is the one case where the
selector trap does not apply. The 86 method and property rows need the class's own selector list, so
they were read from the two full inventories:

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/12.0/dyld_shared_cache_arm64 > inv-12.0.tsv
```

One TSV line per class: `class <name> <superclass> <image> <instance selectors> <class selectors>
<protocols>`. Selector keys carry a `-` prefix in **both** columns, which is what
`carried_by_release` expects (`carried[sign == "-" and "instance" or "class"]["-" .. selector]`), so
the dump is directly comparable to the check.

**Result: 0 of the 86 are carried by 6.1.3, and 0 by 12.0.** 27 of them have an owner class a band
end *does* carry, so for those the selector check was a real question, not a formality.

### Controls, and two traps the controls caught

The reader is only worth a zero if it can find what is there. Eight controls, 8/8 present on each
release: `UIView -setFrame:`, `UITableView -reloadData`, `UIBarButtonItem -tintColor`,
`UINavigationItem -title`, `UIImage -imageNamed:` (class column), `UIView -isHidden`,
`UICollectionView -dequeueReusableCellWithReuseIdentifier:forIndexPath:`, `UISearchBar -text`.

- **The `is`-form.** The 6.1.3 era spells the `hidden` property's getter `-isHidden`, not `-hidden`.
  A property check that looked only for `-<name>` would have reported a false clean. All 41 property
  rows were re-run against the getter, the `is`-getter and the setter; still 0 carried. This matters
  for `UIBarButtonItem.hidden`, whose owner 6.1.3 does carry.
- **Categories are merged.** `UIImage`'s class column holds `-mapkit_imageNamed:` — a MapKit category
  on a UIKit class — so the dump already counts what categories add, which is what the registry check
  counts.

### The early rungs are other classes', measured

`first-rung.lua` over the 107 distinct names: 94 read 16.0, and 13 read earlier. All 13 are
explained, and none of them touches its row:

| name | rung | what 6.1.3 actually says |
|---|---|---|
| `style` | 3.0 | 90 classes carry it, `UINavigationItem` among the 6 that do not |
| `hidden` | 3.0 | 14 classes carry it (`CALayer`, `DOMHTMLElement`, ...); `UIBarButtonItem` is not a view and is not among them |
| `direction` | 3.0 | 25 classes carry it (`CALight`, the DOM HTML classes, `UISwipeGestureRecognizer`); not `UIPageControl` |
| `ordered`, `documentProperties`, `badgeCount`, `export:`, `backAction`, `duplicate:`, `find:`, `alwaysAvailable` | 3.2 – 11.0 | the name is in the index, but **no 6.1.3 class implements it** — the inverse of the documented trap |

### Two rows the SDK's own annotation is wrong about

`UICalendarViewDelegate` and `UISceneWindowingBehaviors` read **18.0**, not 16.0: the 16.0 cache
carries no such name, so the SDK's `introduced` is not corroborated by the cache of the release that
introduced it. Both are recorded in their rows rather than smoothed over. Both are still absent from
every release the band builds, which is the claim the row makes.

## The one row with real demand, and why it is still `absent`

`-[UISearchResultsUpdating updateSearchResultsForSearchController:selectingSearchSuggestion:]` is the
only row of the 115 with demand behind it (2 apps, `CRASH-ON-USE`; rank 68). It was measured rather
than assumed, and the measurement says the port cannot carry it:

- **Both apps DEFINE the selector.** `corpus/defcache/session.json` and `defcache/delta.json` list
  `updateSearchResultsForSearchController:selectingSearchSuggestion:` among the methods the binaries
  define. So the method is the *application's*; any definition the band exported would shadow it.
- **The band cannot export a definition anyway.** A `.m` redeclaring the protocol compiles with
  `warning: duplicate protocol definition of 'UISearchResultsUpdating' is ignored` and the object
  exports **no symbol at all** — the SDK the package compiles against already declares the member, so
  the redeclaration is discarded. `implemented` needs "a definition the band exports"
  (`backports.lua:1932`, `unbuilt`), and this exports nothing: it would fail the gate.
- **A conformer already compiles and dispatches.** Built for `arm64-apple-ios15.0-macabi`, a conformer
  implementing both members compiles (one `-Wunguarded-availability-new` note about the
  `UISearchSuggestion` parameter type), and `respondsToSelector:` answers **YES**, because the
  application's own method answers it.
- **Nothing in the port applies it, and the header says why.** `UISearchController.h:54` scopes the
  trigger to "one of the search suggestion buttons displayed under the keyboard on **tvOS**". This
  port lists no suggestions — `UISearchSuggestion` is a protocol no held release declares (its own row
  is `absent`) — so there is no call site to add without building a suggestion list, which is a
  feature, not a backport.

`inert` was considered and rejected on the same measurement: `inert` means "the symbol loads and
nothing applies it", but the symbol here is the application's, and the band exports none. `absent`
means "nothing the release has answers the name" — measured, 0 at both ends. The `CRASH-ON-USE` label
describes two applications *defining* a selector for a framework release the port is not; it is not
a missing port capability, and no registry row or object changes it.

## The one row whose owner a band end *does* carry, measured on all three rungs

`UIPrintFormatter.requiresMainThread` is the 116th row, and the only one that cited the SDK's own
declaration as its whole `source`. Its owner class is not new in 16.0, so the class-scoped question
is real: does `UIPrintFormatter` carry `requiresMainThread` at either band end?

```
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/12.0/dyld_shared_cache_arm64  > inv-12.0.tsv
REVENANT_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.revenant/dyld/16.0/dyld_shared_cache_arm64e > inv-16.0.tsv
```

```
6.1.3  UIPrintFormatter  super=NSObject  image=.../UIKit.framework/UIKit            selectors=20  requiresMainThread: none
12.0   UIPrintFormatter  super=NSObject  image=.../UIKitCore.framework/UIKitCore    selectors=22  requiresMainThread: none
16.0   UIPrintFormatter  super=NSObject  image=.../PrintKitUI.framework/PrintKitUI  selectors=25  requiresMainThread: -requiresMainThread
```

(The counts are the class's own selectors as `objc-inventory.lua` writes them, `-.cxx_destruct`
excluded, which is what `carried_by_release` and `added_members` count.)

**The control is the same row on the same reader.** Each rung's `UIPrintFormatter` line carries the
class's whole selector list, and it holds the selectors the class is known for — `-drawInRect:forPageAtIndex:`,
`-printPageRenderer`, `-pageCount`, `-copyWithZone:` — while no rung's list holds `requiresMainThread`
in any spelling (`-requiresMainThread`, `-isRequiresMainThread`, `-setRequiresMainThread:`). The
reader found the class and read its selectors; the zero is the release's.

**What the 16.0 line settles.** The SDK says `introduced: "16"` for this row and nothing else did.
The 16.0 cache's own `UIPrintFormatter` carries `-requiresMainThread`, so the release that introduced
it is 16.0, as the SDK's annotation says — the `16` spelling in the row is this file's own shorthand
and the `UICalendarViewDelegate` / `UISceneWindowingBehaviors` rows above, whose SDK annotation the
cache does *not* corroborate, are the two exceptions this file already records.

**Why the row stays `absent`.** Both band ends carry the class and neither carries the accessor, so
nothing a band builds on answers the name. Carrying a getter that answers YES would be carrying an
override point nothing reads: the release's print system has no code that asks (measured above — the
method is not there to ask it), so the value would be stored and never consulted.

## What a reader should take from this

Every row of the file says `absent`, and that is now a measurement rather than a queue entry: **0
carried at 6.1.3, 0 carried at 12.0, control passed in the same run, 8/8 selector controls on each
release, and the `is`-getter form checked on all 41 properties.** No status in this file is wrong.
The rows that could be implemented are the ones whose owner class a band end carries, and each of
those is feature work with its own differential — not something a registry row can settle.

## Two rows whose blocker is a missing declaration, measured rather than assumed

Both of these sat at `absent` with "the port carries X, so this could be built - not
built for lack of demand, not a wall". Reading the two declarations each row depends on
turned both into a mechanical statement about what is missing, which is what a reviewer can
check.

### `UIPopoverPresentationControllerSourceItem`: the protocol object is not transcribed

The row asks for the marker protocol `UIPopoverPresentationControllerSourceItem`. Carrying it is
two things, and neither is written:

```
grep -c UIPopoverPresentationControllerSourceItem packages/a/apple-backports/UIKit/RevenantUIKitProtocols.h
grep -rn "UIPopoverPresentationController.sourceItem" packages/a/apple-backports/registry/
```

```
0                       the protocol is in no band of RevenantUIKitProtocols.h
(no match)              no registry row names UIPopoverPresentationController.sourceItem
```

The first is why a category conformance would be dropped silently. A protocol row the port
carries is emitted by the generated `UIKitProtocols<release>.m`, which names each protocol the
registry lists for that band - and that file only names what `RevenantUIKitProtocols.h` declares
(`protocol_sources()` in `backports.lua:702` imports that header and writes `(void)@protocol(X)`
per row). This protocol is not in it, so no protocol object is emitted and
`attach.c:337` - which adds a category's protocols by resolving their names with
`objc_getProtocol` - finds nothing and adds nothing, while the conformance looks present in the
source. Transcribing it is a `tools/transcribe-protocols.py@52253c0650` run over a shared header other bands
are also editing.

The second is the reason the row is worth little on its own: `sourceItem` is the only API that
consumes the protocol, and no registry row names it, so a caller that could declare a
`UIPopoverPresentationControllerSourceItem` would have nothing to hand it to. The port's popover
hangs from `sourceView` or `barButtonItem` (`UIPopoverPresentationController.md`).

### `UIWindow.safeAreaAspectFitLayoutGuide`: the ratio has nowhere to be enforced

`UIWindow.h:77` declares the protocol the guide exists for:

```objc
@protocol UILayoutGuideAspectFitting <NSObject>
/// Update the aspect ratio (width / height) for the given content
/// Defaults to 1.0. Must be > 0.0 ...
@property (nonatomic, readwrite) CGFloat aspectRatio;
@end
```

so the ratio is a caller's number and the guide's job is to hold `width == height * aspectRatio`
inside the safe area. The port's `UILayoutGuide` has every anchor that job needs and none of the
one it needs to state the relation:

```
grep -n "addConstraint" packages/a/apple-backports/UIKit/UILayoutGuide.m
```

```
(no match)
```

`UILayoutGuide.m` implements `leadingAnchor` through `heightAnchor` and `centerXAnchor` through
`centerYAnchor`, each anchored to the guide's own backing view, but the class carries no
`addConstraint:` of its own - `UIView+SafeAreaGuide.m` reaches the backing view through its own
`-[UILayoutGuide revenant_view]` and adds the constraints to the *view*. Enforcing the ratio on the
backing view would work and would not be the API a caller expects: the caller sets
`aspectRatio` on the guide, and the constraint would have to live somewhere the port does not
expose. Writing `-addConstraint:` on `UILayoutGuide` is the first step, and it is a change to the
iOS 9 object that owns the class, not a 16.0 addition beside it.

That is why the row is `absent` with this reason rather than "no demand": the substrate is
`UILayoutGuide` and the safe area, and the missing step is a constraint API on the guide, named.
