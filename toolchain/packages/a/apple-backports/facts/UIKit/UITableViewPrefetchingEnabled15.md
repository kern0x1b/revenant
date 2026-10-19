# UITableView.prefetchingEnabled, iOS 15.0

One row, one object: `packages/a/apple-backports/UIKit/UITableView+PrefetchingEnabled15.m`.

## What was missing, and why it is a real gap rather than a duplicate

The port has prefetched for table views since 10.0. `UITableView+Prefetching10.m` holds the
prefetch data source, works out which rows sit just past what is on screen, calls
`-tableView:prefetchRowsAtIndexPaths:` and cancels what has scrolled away. It runs as soon as a
data source is set, and **it has no switch**.

The collection view's half of the same feature has one. `UICollectionView+Prefetching10.m:121`
gates its pass:

```objc
if (!source || !self.isPrefetchingEnabled)
    return;
```

and that file's own comment records where the gate's default came from — measured under Mac
Catalyst, a freshly made collection view answers `NO` for `isPrefetchingEnabled` and `nil` for the
data source. Apple's `UITableView` had no such switch in 10.0 and gained one in 15.0, so before
this row the port's table prefetching was the one half of the feature a caller could not turn off:
no way to say "I have set a prefetch data source but not for prefetching", and no way to ask
whether it was on. That is the row.

## The default, and where it comes from

**`NO` until set.** Not chosen here: it is the value measured on the host for the sibling
half of the same feature in the same port, and the row's `source` says so and names the file the
measurement is recorded in. A table view that prefetched until told otherwise would fetch on
scroll for every caller who set a data source, which is not what Apple's table view does.

## How the gate is applied, and why it is a `+load` hook

The pass is started by a `layoutSubviews` hook installed in `UITableView+Prefetching10.m:43`.
That file is a **10.0** object and this one is **15.0**, so the gate is not added inside it: an
ivar and a check there would make one file carry API from two releases, which is the object
`band()` (`backports.lua:776-789`) and `tools/release-split.lua` both refuse.

Instead this file installs its own `layoutSubviews` replacement, exactly as the 10.0 file does,
and `+load` is required because it runs before the library's categories are attached — a method
added from a category would not be there yet, which is the reason
`UITableView+Prefetching10.m:15` spells that out.

**Two hooks on one selector compose, and that was measured rather than assumed.** Two classes
each calling `class_replaceMethod` on `-layoutSubviews` in their `+load`, the second reading the
IMP the first installed, and one `-layoutSubviews` call afterwards runs: the original, then the
first hook, then the second. So the 10.0 pass still happens exactly once, and the gate is what
decides whether it happens at all.

`class_getInstanceMethod` / `method_getImplementation` / `class_replaceMethod` /
`imp_implementationWithBlock` are the Objective-C runtime's public documented API for replacing an
implementation, and they are the mechanism the tree already uses in
`UICollectionView+Prefetching10.m` and `UITableView+Prefetching10.m`. This is not a private
selector, an ivar read by name, or an offset.

The install returns early when the release already answers `-isPrefetchingEnabled`, the same
guard the collection view's file uses at `:35` — so on a release that has the switch natively,
this file adds nothing and defers to it.

## The one cross-object call, and why it is a message send

The hook calls `-charon_prefetchRows`, which `UITableView+Prefetching10.m` defines. The two files
are separate objects and separate `band()` decisions, so a band could keep this one and leave the
10.0 one out. The call is therefore **sent, guarded by `respondsToSelector:`**, not made as a C
call: a message send is a no-op when nothing implements it, where a C symbol would be
`Undefined symbols` at link time in exactly that band (`AGENTS.md`, "A C function shared between
backport files"). This file defines no C function of its own for the same reason.

The storage is a `static const char` key local to this file, so the 10.0 object and the 15.0 one
cannot read each other's state even when both are linked into one binary.

## What was checked, and what was not

**This file compiles.** It was checked with the same flags `review-mechanical.sh` uses - `xcrun clang -target armv7-apple-ios6.1.3 -isysroot <iPhoneOS16.4.sdk> -fobjc-arc -Os -g0 -Wall -Wno-unguarded-availability-new -Wno-unguarded-availability -Werror=objc-missing-property-synthesis -fsyntax-only` - and it builds with zero errors and zero warnings. What has **not** happened is a link into a band or a run on a device, and that is the gate's.

This file is the one the review caught hardest: its `#import` lines and both category
declarations had ended up **below** the `+load` installer that sends their messages, so it
compiled against a `UITableView` that did not exist yet — *"cannot find interface declaration for
'NSObject'"*, then *"use of undeclared identifier 'UITableView'"*, `'Method'`, `'IMP'`,
`'class_replaceMethod'`, and finally *"property 'charon_prefetchingAllowed' not found"* and *"no
visible `@interface` for 'UITableView' declares the selector 'charon_prefetchRows'"*. All of it
was ordering, and the order is now: storage key, the two declarations, the installer, the category.
Moving them also removed a duplicate definition of the storage key the reshuffle had introduced.

Checked before the compiler, and worth keeping:

- every selector the file calls exists in the port or the SDK — `-respondsToSelector:`,
  `-instancesRespondToSelector:`, `-class_getInstanceMethod`, `-method_getImplementation`,
  `-class_replaceMethod`, `-imp_implementationWithBlock` and the four runtime functions are
  public API, and `-charon_prefetchRows` is declared and defined in `UITableView+Prefetching10.m`
  (`:18` and `:106`);
- the two-hook composition above was **run** on the host, in a file of the same shape with two
  installers and one instrumented original, and the output is what the comment claims;
- the default is quoted from the tree's own recorded measurement, not from a header.
