# The UIKit constants first exported by iOS 9.0

`UIKit/UIKitConstants90.m`. 2 constants, one object, and every value read out of a real dyld
shared cache rather than taken from a header or from a host framework.

The reader is `tools/corpus/cache-value.lua` over this repository's own cache reader
(`modules/apple/dyld.lua`). It is checked before any value is taken: on each cache of
the ladder, eight constants whose value is their own name are read back, and a cache
that reproduces none of the ones it holds contributes nothing. On this ladder every
cache reproduced all eighteen of the checked strings it holds, and no constant's
value differed between caches.

| constant | the release it was read from | the value |
| --- | --- | --- |
| `UIUserNotificationActionResponseTypedTextKey` | 9.0 | `@"UIUserNotificationActionResponseTypedTextKey"` |
| `UIUserNotificationTextInputActionButtonTitleKey` | 9.0 | `@"UIUserNotificationTextInputActionButtonTitleKey"` |

## The release each object carries

A band links one object per release and an object carries the API that arrived in
one release: an object that defines a symbol the band already has together with one
it does not is refused at link time (`modules/apple/backports.lua`, `band()`). The
release above is the first *held* release that exports every symbol in the file,
measured symbol by symbol over `~/.charon/dyld`, so the file is kept by every band below that
release and reexported by the release's own from that one on.
