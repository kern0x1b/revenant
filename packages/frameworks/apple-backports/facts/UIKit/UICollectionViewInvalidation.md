# UICollectionViewLayoutInvalidationContext, iOS 7.0

Introduced in iOS 7.0: the object a collection view layout is invalidated with, saying which
items, supplementary views and decoration views changed and by how much the content moved,
and the flow layout's own subclass with two flags.

Source: the host's own UIKit under Mac Catalyst, asked for each answer below and held against
the backport by `tests/backports/host/invalidation/run.sh`, fifteen records that the app
`tests/backports/device/invalidation.m` compares on a device running 6.1.3.

## The context

- A new context has no index paths - the three properties are **nil**, not empty - both
  adjustments zero, and `invalidateEverything` and `invalidateDataSourceCounts` NO.
  Those two have no setters in the header and stay NO for a context an application makes.
- `-invalidateItemsAtIndexPaths:` keeps the paths **sorted** by `-compare:` and without
  duplicates, however often it is called and in whatever order; the array is a copy.
- The supplementary and decoration properties are dictionaries from the kind to a sorted,
  duplicate-free array; the kind is added by each call.
- The offset and size adjustments are plain values.
- The flow context is a subclass whose two flags, delegate metrics and attributes, are YES at
  first and can be set.

## The layout

- `+invalidationContextClass` is the base context class, and the flow context class for a
  flow layout.
- `-invalidationContextForBoundsChange:` answers a new context of that class with nothing
  marked.
- `-invalidateLayout` calls `-invalidateLayoutWithContext:` once with a new context of the
  layout's class; the default of that method does the invalidation and **does not** call an
  application's `-invalidateLayout` again. Called with a context by an application, an
  override of `-invalidateLayout` is not called.

## What the port answers, and what iOS 6 does with them

The release's layouts know `-invalidateLayout` only. The port routes it through
`-invalidateLayoutWithContext:` so an override there runs, as it does on iOS 7 and later, and
the default falls through to the release's own invalidation. The release calls
`-shouldInvalidateLayoutForBoundsChange:` and then `-invalidateLayout`, so an override of
`-invalidationContextForBoundsChange:` is never asked for its context and a context arrives
unmarked; nothing in the context is used to invalidate less.
