# UIDeferredMenuElement, iOS 14.0

Introduced in iOS 14.0: a placeholder in a menu whose real elements arrive later from a provider block.

Source: the host's own UIKit under Mac Catalyst (macOS 27.0), held against the backport by
`tests/backports/host/uikit2` (the `menus` group).

## As UIKit does

- `+elementWithProvider:` keeps the block, and accepts nil. The title is the localised `Loading…`; there is no image.
- The element copies to itself, and equals only itself: two made from the same block are two elements.
  `-description` is `<UIDeferredMenuElement: 0x...>`.
- Archiving writes a fulfilled flag (not yet), the caching flag and the identifier; an element read back has no provider,
  and the port answers an empty list for it.
- The provider is called once, the first time the element is met in a menu, and its answer is kept.

## What the port does with it

The port's context menu asks the element for its elements when it builds a sheet and waits at most 1.5 seconds for the answer.
An element that has not answered by then is left out of that sheet, and its late answer is kept for the next time. Elements the
provider hands back that are themselves deferred are dropped; one level is resolved.

`+elementWithUncachedProvider:` (15.0) is carried alongside `+elementWithProvider:`: the two differ only in
whether the element remembers the provider's answer. A cached element (`+elementWithProvider:`) calls its
provider once and hands the same elements back to every later fulfil; an uncached one calls the provider
fresh every time the port's context menu asks it to fulfil, exactly as the SDK header documents. The
caching flag is archived as `cachesItems` and read back the same way; a decoded element with no provider
answers an empty list either way, since the provider itself is never carried across archiving (see above).
