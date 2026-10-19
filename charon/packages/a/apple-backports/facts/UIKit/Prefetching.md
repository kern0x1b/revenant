# Prefetching, for a collection view and a table view

Prefetching is asking a data source for the items or rows that are about to come on screen, before
they are asked for as cells. The release has no prefetching of either kind, so the port asks itself:
after the view has laid out, the candidates are the ones just past what is on screen, ordered by how
far they are from it, nearest first — the order the headers ask them in — and the ones that were
candidates and are not any more are called off, so a data source fetching images stops fetching the
ones scrolled past.

## How the trigger is attached

Neither view has a prefetching call to hook, so the port adds one: an installer whose `+load`
replaces `layoutSubviews` on the class, guarded by `instancesRespondToSelector:` so a release that
already prefetches is left alone. The method is added with `class_replaceMethod` from `+load` rather
than from a category, because `+load` runs before the library's own categories are attached and a
method added from a category would not be there yet (the same reason `UIViewController+DocumentMenu.m`
keeps a same-selector category beside its replacement).

The candidates are the items in the sections on screen, one and three rows either side for a table
and one either side for a collection, each asked for once and each called off once. Nothing is asked
at all until a data source is set, and on a collection view not until `prefetchingEnabled` is on,
which is `NO` in a view made by hand as the host answers.

A prefetch data source is held with `OBJC_ASSOCIATION_ASSIGN`, the way the tree holds a weak sender
(`UIAction.m`, `UICommand.m`), because a release this old has no weak associated object.

## What is not verified

**The prefetching inside a live view is device-unverified**, for the reason the transition and the
reordering are: a UIKit app started by `xmake emulate` never reaches
`application:didFinishLaunchingWithOptions:`, and these cases need a window and a laid-out view.
What *is* measured is the host's own default for a fresh view (`tests/backports/host/uikitconst`
records it) and the headers' own contract for the order and the arguments.
