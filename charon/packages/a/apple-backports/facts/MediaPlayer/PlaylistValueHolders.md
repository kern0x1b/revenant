# Playlist value holders: the 8.0 seedItems key, the 8.0 accessor, and the 9.3 creation metadata

Three rows that arrived saying the class "arrived in iOS 9" or that a property "arrived in iOS 8". Two of
them are carryable and one row's key had to be **read** rather than derived, and the reading is what this
page exists for.

## `MPMediaPlaylist.seedItems` — carryable, and the release holds the accessor

`MPMediaPlaylist` is PRESENT on 6.1.3 with **15 own instance methods**:

```
-count  -encodeWithCoder:  -existsInLibrary  -hash  -initWithCoder:  -initWithPersistentID:
-isEqual:  -items  -loadGeniusMixArtworkWithTileLength:completionBlock:  -mediaTypes  -name
-persistentID  -playlistAttributes  -representativeItem  -valueForProperty:
```

`-seedItems` is in none of them, and across all **11378** classes of the whole 6.1.3 cache exactly **zero**
declare it, so no category in any framework supplies it either.

What makes it carryable is `-valueForProperty:`, which **is** one of the 15. The header declares the
property as a named key over it — `MP_EXTERN NSString * const MPMediaPlaylistPropertySeedItems;` beside
`@property (nonatomic, readonly, nullable) NSArray<MPMediaItem *> *seedItems MP_API(ios(8.0));`. Same shape
as the two 9.3 keys `MPMediaPlaylist93.m` already carries.

**The key shadows nothing, and that was checked rather than assumed.** 6.1.3 exports none of MediaPlayer's
36 constants, so the port carries this one. But it is carried *safely* because the declaration in
`MPMediaPlaylist.h` carries **no `MP_API` annotation at all**, while the two 9.3 keys beside it carry
`MP_API(ios(9.3)`. An unannotated extern is unversioned, so this name is not something a later release
introduced and the port's copy is not standing in for a 6.1.3 symbol that exists.

## The key's value was read, not derived — and the convention is false in general

The port's convention for these keys has been "the value is the property's own name". **That is false for
the two keys beside it**: `MediaPlayerConstants.md:8-12` records
`MPMediaPlaylistPropertyAuthorDisplayName` = `"externalVendorDisplayName"` and
`MPMediaPlaylistPropertyDescriptionText` = `"descriptionInfo"` — neither is the name of the constant or of
the property. So a value spelled from this key's name would have been a guess dressed as a fact.

Read from Apple's own framework by `tests/backports/host/mediaplayeritem/seedkey.m`, which links
MediaPlayer and prints three values plus a negative control — the two known ones are in the same run so
the reader is shown live:

```
MPMediaPlaylistPropertySeedItems          seedItems
MPMediaPlaylistPropertyAuthorDisplayName  externalVendorDisplayName
MPMediaPlaylistPropertyDescriptionText    descriptionInfo
MPMediaPlaylistPropertyAKeyNoFrameworkHas (nil)
```

So for *this* key the convention happens to hold, and that is a fact about this key, not a rule. One of
three holds its own name.

## The type is the whole content of `-seedItems`

`-valueForProperty:` returns `id`; the header declares `nullable NSArray<MPMediaItem *> *`. So a value of
the wrong type is **refused, not forwarded**, at two levels: the container must be an `NSArray`, and every
element must be an `MPMediaItem`.

**The array test is not defensive tidiness, and the check proves it by crashing.** Mutating the object to
drop the container test does not make `playlistvalueholders.m` print RED — it makes it *die*:

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason:
'-[__NSCFConstantString countByEnumeratingWithState:objects:count:]: unrecognized selector sent to instance'
```

because the caller then sends an array message to the string the release happened to hold under the key.
That crash is a stronger verdict than a RED line, and it is the reason the guard exists rather than
something the file could have left out.

Dropping the **per-element** test does print RED, twice, because the check asks for a mixed array
(`@[a, @"not an item"]`) and expects the whole answer nil rather than an array declared to hold items that
does not.

An **empty** array is a real answer and is distinguished from nil by the check, because a caller testing
`if (playlist.seedItems)` should see an empty Genius mix differently from a playlist that is not one.

## `MPMediaPlaylistCreationMetadata` — carryable, and one contract honoured

ABSENT from both 6.1.3 and 4.3, so new code and nothing to shadow. The header gives it one designated
initializer and three properties, so it is a value holder.

**`null_resettable` on `authorDisplayName` is a contract, and it is the interesting part.** The header's own
comment says "Defaults to the requesting app's display name" — so `nil` does not mean *no author*, it means
*not set, use the app's name*. The getter therefore answers the **main bundle's own display name** and
never nil.

The lookup is real, and the fallback chain is three deep **because a measurement demanded the third step**:

```
CFBundleDisplayName  ->  CFBundleName  ->  -[NSProcessInfo processInfo] processName
```

The first draft answered nil for a bundle with neither Info.plist key, and the check caught it — the host
check is a bare command-line binary whose plist carries neither, and two lines went RED ("never set" and
"reset to nil"). `null_resettable` promises an answer for nil, so a getter that can return nil breaks its
own promise.

Not `-[NSBundle bundleName]`, which the first draft used: it is **macOS-only**, and the iOS SDK declares no
such selector — `no visible @interface for 'NSBundle' declares the selector 'bundleName'`, measured. The
Info.plist key is the same string that accessor would have read.

`MP_INIT_UNAVAILABLE` is compile-time here too, so no `-init` is declared: the header's designated
initializer is the only way in.

## What this family does not do, and why the limit is not on the class

`MPMediaPlaylistCreationMetadata` is the argument to
`-[MPMediaLibrary getPlaylistWithUUID:creationMetadata:completionHandler:]`, and **that method stays
`absent`**: the release has no iCloud music library, and `MPMediaLibrary`'s own 110 instance and 23 class
methods are all local-library work.

So the class is constructible and its three properties work, and nothing on this release can send it
anywhere. Those are two different questions — *can this object be built* (yes) and *is there an endpoint to
send it to* (no) — and the two rows answer them separately rather than one status covering both.

## The check, and its mutants

`tests/backports/host/mediaplayeritem/playlistvalueholders.m` — 9 checks, 0 failures, re-run on
2026-10-03. It used to open with a check comparing the port's own `MPMediaPlaylistPropertySeedItems`
against the literal `@"seedItems"`, which is the code under test compared with itself; that check is
gone, and the key's value is certified only by `seedkey.m` above, which reads Apple's framework and
includes none of this port. The file also included `MediaPlayerConstants80.m` after the key had moved to
`MediaPlayerConstants30.m`, so on main it stopped linking (`_MPMediaPlaylistPropertySeedItems`
undefined); it includes the 3.0 file now.

| mutation | verdict |
| --- | --- |
| `seedItems`'s per-element kind test removed | `RED` ×2 |
| `authorDisplayName`'s null_resettable default removed | `RED` ×3 |
| `seedItems`'s **array** test removed | **the check CRASHES** — `-countByEnumeratingWithState:` on a string |

Two defects were found by compiling and running, neither visible by reading:

- the `null_resettable` chain answered nil for a bundle with no display name;
- the first draft of `MediaPlayerConstants80.m` declared its extern with no `#import` at all and failed
  with `unknown type name 'NSString'`.

And one of the three stand-in classes had to be given an `@implementation` as well as an `@interface`,
because the link failed with `_OBJC_CLASS_$_MPMediaPlaylist` and `_OBJC_METACLASS_$_MPMediaPlaylist`
undefined — the same class of defect as `MPSystemMusicPlayerController` in `QueueDescriptors.md`. A
subclass needs its superclass implemented, which the metaclass reference makes explicit.
