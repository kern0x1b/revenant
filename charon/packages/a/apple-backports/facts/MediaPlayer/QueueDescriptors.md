# The queue-descriptor family: 10.1's three classes, 10.3's three, and 11.0's two

Fourteen rows that arrived saying "the class arrived in iOS 10.1, and nothing in iOS 6 does its work or stands
in for it". That the release carries none of the fourteen names is measured and true. It is not the question
for any of them, and the family splits cleanly in two once the release's own surface is read.

## The read that decides the family

Class-scoped, `tools/corpus/objc-inventory.lua` over the armv7 caches of 6.1.3 and 4.3 through
`coordination/heavy.sh`, one per turn; the commands are in `LanguageOptions.md`. Controls as that page
records — `MPNowPlayingInfoCenter` PRESENT at 6.1.3 and ABSENT at 4.3, so the reader discriminates.

All eight classes read ABSENT at both ends. `MPMusicPlayerController` reads PRESENT at both, and **its own
method list is what the family turns on**: 66 own instance methods and 5 own class methods at 6.1.3, 52 and 5
at 4.3.

| queue setter on 6.1.3 | release | public in the SDK header? |
| --- | --- | --- |
| `-setQueueWithQuery:` | PRESENT | yes |
| `-setQueueWithItemCollection:` | PRESENT | yes |
| `-setQueueWithQuery:firstItem:` | PRESENT | **no** |
| `-setQueueWithSeedItems:` | PRESENT | yes |
| `-setQueueWithGeniusMixPlaylist:` | PRESENT | yes |
| `-setQueueWithStoreIDs:` | **absent** | yes (9.3) |
| `-setQueueWithItemIDs:` | **absent** | no |

## The split, and why it is a split and not a gap

**A media-item descriptor is real, because a release setter consumes it.** It holds a query or an item
collection, and the release has `-setQueueWithQuery:` and `-setQueueWithItemCollection:` as its own public
methods. So `-setQueueWithDescriptor:` translates onto them at the release's own argument order, and the
caller hears its queue back through the release's own `-nowPlayingItemAtIndex:`. The check proves it: the
stand-in `MPMusicPlayerController` records which release setter it was asked to call, and
`queuedescriptor.m` asserts `setQueueWithQuery:` and `setQueueWithItemCollection:` — and that mutating the
bridge to call neither turns the check RED (2 and 5 RED lines respectively).

**A Store descriptor is carried and not played.** The release has no setter taking a Store ID in any
spelling at either end, and there is nothing to resolve an ID to: `MPMediaItem.playbackStoreID` is on 0 of
the 113981 distinct selector names and none of the release's `MPMediaItem` getters is declared anywhere in
it (`AbsentRows.md`). Calling `-setQueueWithQuery:` with a query fabricated out of Store IDs would be a
different API's answer under this method's name. So the class is delivered, holds what the caller gave it,
and the setters leave the queue alone. The check asserts that **no** release setter is called for it.

**Append and prepend call nothing, and that is the whole answer.** All five release setters *replace* a
queue. There is no append, and no way to read the current queue as a value to re-set it with one item added
— `-nowPlayingItem` is the item being *played*, `-nowPlayingItemAtIndex:` indexes by position, and neither
returns the queue. Rebuilding it in memory would change which item plays next and lose the release's own
start item. Both are `void` in the header, so there is no error channel and none is invented.

## The private method this port did not call

`-setQueueWithQuery:firstItem:` is among the release's 66 own methods and is *exactly* what a descriptor's
`startItem` wants — a query plus the item to start at. It is also declared by **no** SDK header: the public
queue setters in the 16.4 header are the six in the table above and the two-argument form is not among them.
So it is a private framework method, and calling it would be a private-API trick where a public one exists.
The `startItem` is held and not applied, and the file says so.

## Two `MP_INIT_UNAVAILABLE` classes, and what that costs to implement

`MediaPlayerDefines.h:70-73` expands the macro to:

```
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
```

That is a **compile-time** attribute, and it is the sharpest constraint in this family. Both
`MPMusicPlayerQueueDescriptor` (10.1) and `MPMusicPlayerControllerQueue` (10.3) carry it, so **no subclass
initializer in this library may call `[super init]`** — measured, three `'init' is unavailable` errors in the
10.1 object before this was addressed, one per header initializer. A base `-init` that merely refused at
runtime would not have helped; the rejection happens before the body exists.

The fix in both cases is a base initializer with a name of its own, which the concrete subclasses call. Both
are registered as rows (`mpqueedescriptor.json`), because a seam the port owns still needs a registry row —
the rule `AGENTS.md` records after a reviewer's verdict on a helper that carried no release.

Each is also declared exactly **once**, on the class that implements it. Restating the 10.1 declaration in
the 11.0 object was tried, to avoid depending on include order, and produced
`duplicate definition of category 'CharonSubclassInit' on interface 'MPMusicPlayerQueueDescriptor'`.

The runtime refusal is separate and by class comparison — `if ([self class] == [Base class])` — because
both concrete subclasses go *through* the base initializer on their way to being objects. A base that always
raised would make every real initializer throw.

## The `uint64_t` that is not an `NSNumber`

`MPMediaEntityPersistentID` is `typedef uint64_t` in **both** SDKs — `MPMediaEntity.h:15` in 16.4 and in
26.2. The 10.1 object's per-item windows are keyed by the boxed value, and a zero persistent ID is the
"no identity" case, declined rather than keyed by object address.

`MPMediaItemStandin.h` declares `typedef NSNumber *MPMediaEntityPersistentID` and its comment says "the
framework spells the identifier type as a typedef over NSNumber". **That comment is wrong about the
framework**, and following it cost two failed builds: the unboxed spelling fails against the real SDK
(`type argument 'MPMediaEntityPersistentID' (aka 'unsigned long long') is neither an Objective-C object nor a
block type`) and the boxed spelling fails against the stand-in (`illegal type ... used in a boxed
expression`). Boxing satisfies both. The stand-in's comment is **not** corrected by this band — it is shared
with the `MPMediaItem` family, whose generated getters depend on the stand-in's own typedef, and changing it
is that family's call, not this one's.

## A class no SDK header declares

`MPSystemMusicPlayerController` appears in **no** MediaPlayer header in 16.4 or in 26.2, and the release
carries no such class. It is declared and implemented here because the method row naming it is a real public
row and a category cannot be written on a class that does not exist. Two defects were found by compiling
it, neither visible by reading:

- an `@interface` alone is not enough — `_OBJC_CLASS_$_MPSystemMusicPlayerController` is **undefined at link
  time** (`Undefined symbols for architecture arm64`, naming the category);
- a category on a class declared in the same file needs that class *implemented* too.

The `@implementation` is empty on purpose: the class is `MPMusicPlayerController`'s system-music sibling, so
what it can honestly be is what it inherits — the release's own playback accessors.

## The check, and three mutants that could not fail

`tests/backports/host/mediaplayeritem/queuedescriptor.m` — 20 checks, 0 failures, against an empty stand-in
`MediaPlayer/MediaPlayer.h` for the same reason as `playablecontent.m`: this Mac has these classes.

| mutation | verdict |
| --- | --- |
| bridge stops calling `-setQueueWithQuery:` | `RED` ×2 |
| the item-collection branch disabled | `RED` ×5 |
| `-removeItem:`'s membership test replaced by `if (1)` | **`OK (0 failures)`** |
| the completion handler called twice | **`OK (0 failures)`** |

**Two of those do not fail, and both are recorded rather than quietly dropped.**

The membership test in `-removeItem:` is a **shortcut, not the correctness of the removal**:
`-removeObject:` on an object the array does not hold is already a documented no-op, so the queue would be
unchanged either way. What the test buys is that `-charonSetItems:` is not called for a removal that changed
nothing. The file's comment now says exactly that, instead of claiming a guarantee the mutation shows is not
there. A check that removes only an item that *is* present was added anyway, because it is the case a
caller hits.

The double-handler mutation **never applied** — it was written against the check's own `main` rather than
the port's call site, so it tested nothing. A second call with its own handler was added so the claim "called
exactly once" is asserted per call rather than once overall.

## One object per release, and the exception this family states

Four files: `MPMusicPlayerQueueDescriptor101.m` (10.1 classes), `MPMusicPlayerControllerQueueDescriptor101.m`
(10.1 setter, 10.3 pair, 11.0 method), `MPMusicPlayerApplicationController103.m` (10.3 classes),
`MPMusicPlayerPlayParameters11.m` (11.0 classes).

The second mixes three releases, and that is deliberate and stated in the file and in all three of its
rows. The reason is the trap in `AGENTS.md` under "A C function shared between backport files": a helper
defined in a file that exports one band's API is **left out** of the bands that do not export it, so the
reference is `Undefined symbols` in later bands only — `backports-gate` links one band and passes, and only
the all-band canon build shows it. Every row carries its own `introduced`, which is what `band()` places on.
`release-split` reads band points only, so it cannot see this; the exception is in the prose instead.
