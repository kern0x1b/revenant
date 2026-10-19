# The one 18.0 row a second reader contradicts: `-accessibilityHitTest:withEvent:`

**What this page settles.** `registry/UIKit/ios17-18.json`'s row for
`-[NSObject accessibilityHitTest:withEvent:]` (`introduced` 18.0) sat at `absent` with a `reason`
asserting that the release has no point-based accessibility hit test at all:

> hit testing for accessibility is the release's UIAccessibility query, which reads the tree a UIView
> builds and not a point passed to an object

**That reason is false against both band ends, and the row is still `absent`.** The release's own
`NSObject` carries a point-and-event hit test under a private spelling, and a point-only one under a
public name. So the reason is replaced with the measured one, and the status does not move: what the
release lacks is the *public* two-argument spelling, which is what an application links and sends.

## The measurement, and the command that reproduces it

Class-scoped, with the driver's own `apple.objc` reader, over both armv7 band ends:

```sh
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7   > inv-4.3.tsv
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 > inv-6.1.3.tsv
```

Each `inv-*.tsv` line is `class<TAB>name<TAB>superclass<TAB>image<TAB>instance selectors<TAB>class
selectors<TAB>protocols`, and a stored selector carries its sign (`-text`, `+blackColor`).

**The four selectors, read out of the `NSObject` line of each file:**

| selector | 4.3 armv7 | 6.1.3 armv7 |
|---|---|---|
| `-accessibilityHitTest:withEvent:` (the row's name) | **absent** | **absent** |
| `-_accessibilityHitTest:withEvent:` (private spelling) | **present** | **present** |
| `-accessibilityHitTest:` (public, point only) | **present** | **present** |
| `-_accessibilityHitTestShouldFallbackToNearestChild` | **present** | **present** |

## The control, because a zero is ambiguous on its own

Eight members each band end certainly carries, looked up in the same read, **8/8 on both rungs**:

| member | 4.3 | 6.1.3 |
|---|---|---|
| `-UITextView text` | found | found |
| `+UIColor blackColor` | found | found |
| `+UIColor clearColor` | found | found |
| `-UITableView reloadData` | found | found |
| `-UIViewController viewDidLoad` | found | found |
| `-UITabBarController selectedViewController` | found | found |
| `-UITabBarController setViewControllers:animated:` | found | found |
| `-NSObject accessibilityHitTest:` | found | found |

A rung that finds eight members of the very class in question is what makes the zero on the row mean
the release's and not the reader's.

## Three defects this reader hit, each of which had produced a wrong answer first

Recorded because each one silently reported an absence, and a reader who trusted it would have written
a row from it.

1. **A class method's selector is stored under `-`, not `+`.** `UIColor blackColor` is in the
   *instance* column of `UIColor`. A lookup that trusts the sign finds the eight-member control at 7/8
   on both rungs and prints nothing wrong — it just quietly reports every class method absent. Ten rows
   of the 18.0 family are class methods, so this would have emptied the band.
2. **`NSObject` is both a class and a protocol in these caches.** Keying a lookup by name alone lets the
   protocol's 19 selectors mask the class's 489, and every class-scoped question about `NSObject`
   answers from the wrong table. Measured: the two lines are `class` with 489 instance + 92 class
   selectors, and `protocol` with 19, and the merged key reports 19. This is the trap that made the
   first two runs of this page report `NSObject` as carrying no accessibility selector at all.
3. **The selector table and the class table disagree, and the class table is the one that answers.**
   `~/.charon/dyld/4.3/selectors_armv7.txt` lists `accessibilityHitTest:withEvent:` — with the
   underscore, as a `__objc_methname` string — which reads at a glance as the row's own name. It is the
   private spelling, and a grep over that file is not a class-scoped measurement.

## Why the row stays `absent`, and what a caller gets

The public two-argument selector is absent from both band ends, so an application that names it does not
link against the release's UIKit and `respondsToSelector:` answers honestly NO. The port does not
declare it either: the only implementation either release offers is the private
`_accessibilityHitTest:withEvent:`, and calling a private selector is exactly what this port does not
do.

What a caller gets instead, read off `UIAccessibilityElementSuperCategory` in the same two files, which
is where the release keeps the public accessibility surface on a view:

| member | 4.3 | 6.1.3 |
|---|---|---|
| `-accessibilityHitTest:` (on `NSObject`, point only) | present | present |
| `-accessibilityFrame` | present | present |
| `-accessibilityLabel` / `-accessibilityValue` / `-accessibilityHint` / `-accessibilityTraits` | present | present |
| `-accessibilityCenterPoint` | present | present |
| `-accessibilityZoomInAtPoint:` / `-accessibilityZoomOutAtPoint:` | present | present |
| `-accessibilityActivationPoint` | **absent** | present |

So the release answers a point-based accessibility query, through `-accessibilityHitTest:` and the
element surface beside it, and what it does not carry is the public spelling that takes the event
alongside the point. `UIAccessibilityElement` itself holds only three public accessibility members
(`-accessibilityDelegate`, `-initWithAccessibilityContainer:`, `-setAccessibilityDelegate:`) on both
rungs, so the query path is the supercategory's and not the element's.
