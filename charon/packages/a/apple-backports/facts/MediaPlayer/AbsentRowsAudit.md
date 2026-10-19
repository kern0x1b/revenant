# Nine MediaPlayer rows that stay `absent`, and the measurement each one now cites

The last nine rows of `coordination/corpus/queue/UNIT-MediaPlayer-absent_MediaPlayer.tsv`. Every one of them
keeps its status, and what this band changed is **what each row's `source` names**: all nine said "SDK 16.4,
MediaPlayer", which is a citation of Apple's own declaration and not a measurement, and a row naming a tool
without a command a reader can run is an assertion.

That distinction is the queue rulebook's, and it is measurable: of the 78 rows this file held when the band
started, **26 named a measurement and 52 cited only the SDK**. Every row this band moved out of the file
carries a command. These nine are the rows where the answer could not change — the release carries none of
the names — so the deliverable is proving that at both band ends, with a control, and recording it.

## The two reads, and their controls

Class-scoped, `tools/corpus/objc-inventory.lua`, through `coordination/heavy.sh` in the slow lane, one cache
per turn. The commands are in `LanguageOptions.md`; these are the same two files.

| name | 6.1.3 | 4.3 |
| --- | --- | --- |
| `MPAdTimeRange` | ABSENT | ABSENT |
| `MPNowPlayingSession` | ABSENT | ABSENT |
| `MPNowPlayingSessionDelegate` | ABSENT | ABSENT |
| `MPAdTimeRange` selectors, whole cache | 0 of 11378 classes | — |
| `MPNowPlayingInfoCenter` (control) | **PRESENT** | **ABSENT** |
| `MPVolumeView` (control) | PRESENT | PRESENT |

`MPNowPlayingInfoCenter` is what makes the zeros mean something: the same reader, the same two files, a YES
and a NO. A reader that answered NO to everything would have produced this page for the wrong reason.

The protocols come from the same file's **1171 protocol lines**, because a protocol's absence is invisible to
a per-image `__objc_classlist` read.

## Why each stays `absent` and is not `implemented`

`absent` is for a row whose answer needs a thing the device lacks. Each of these nine names one:

- **the four 9.3 cloud methods** need an iCloud music library. There is none on 6.1.3, and the release's own
  cloud classes — `MPCloudController`, `MPCloudDownloadButton`, `MPCloudAssetDownloadController` — are an
  *app's own download cache*, which is a different thing. `MPMediaLibrary`'s 110 instance and 23 class
  methods are all local-library work, and `MPMediaPlaylist`'s 15 own methods hold **no mutator at all**:
  `-count`, `-items`, `-persistentID`, `-valueForProperty:`, `-playlistAttributes`, `-mediaTypes`,
  `-representativeItem`, `-existsInLibrary`, `-isEqual:`, `-encodeWithCoder:`, `-initWithCoder:`,
  `-initWithPersistentID:` and the artwork loader.
- **`setQueueWithStoreIDs:`** needs a Store ID resolved to an item, and nothing can: `MPMediaItem.playback-
  StoreID` is on **0** of the 113981 distinct selector names, and none of the release's 22 `MPMediaItem`
  getters is declared anywhere in it. Two independent reads, so a store queue on this device has no items at
  all.
- **`MPAdTimeRange` and `MPNowPlayingSession`** need a session surface. 6.1.3's MediaPlayer has none: no such
  class among the release's classes, and `MPNowPlayingInfoCenter`'s own **5** instance methods are
  `_pushNowPlayingInfoAndRetry:`, `setNowPlayingInfo:`, `nowPlayingInfo`, `_init` and `init`, with one own
  class method, `+defaultCenter`. So `canBecomeActive` has nothing that could answer YES, `active` would be
  NO on every call, and `MPAdTimeRange`'s one `CMTimeRange` would be a stored value nothing reads.
  `CMTimeRange` is a CoreMedia struct and reads ABSENT from an Objective-C inventory for that reason — it is
  not a class — so the row's absence rests on its owning class, not on the struct.
- **`MPNowPlayingSessionDelegate`** describes a session that cannot exist. Its callbacks,
  `-nowPlayingSessionDidChangeActive:` and `-nowPlayingSessionDidChangeCanBecomeActive:`, are on **0** of the
  113981 names.
- **`NSUserActivity.externalMediaContentIdentifier`** is a category on a class the release does not have. The
  **class** arrived in 8.0 — `first-rung.lua` answers 8.0 — and it is in neither cache: the 6.1.3 inventory
  holds 848 UIKit and 418 Foundation classes and `NSUserActivity` is in neither, at either end. A category on
  a missing class compiles, links, and then never installs.

## The one that is a category, and why that is worse than nothing

`NSUserActivity.externalMediaContentIdentifier` deserves its own paragraph because "carry it" is the obvious
wrong answer. The port could declare the accessor pair on a class it also declares, and then the row would
be `implemented`. But a category on a class the release does not have makes no metadata: the image would
carry a category nobody can attach, and the row's own `effect` sentence — "respondsToSelector: answers
honestly" — would be a claim about a class that does not exist. That is the same finding as ARKit's
conformance-only category in `ef271700`, where the dylib had **0** occurrences of the name. `absent` is
honest; an `implemented` that installs nowhere is not.

## What these nine are not

None of them is `ignored`. `ignored` means *the release carries the name and the port declines to*, and the
gate answers that branch by checking the release — a row listed as ignored because the release carries it,
when the release does not, is a defect. Every row here is the opposite: the release does not carry it.

None is `inert` either, which needs the symbol to load and nothing to apply it. There is no symbol here.

## The measurement each row now cites, in one line

Every row's `source` now names the command a reader can run and what it prints, in this shape:

```
CHARON_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
  ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 | grep -c '^class<TAB>NAME<TAB>'   # 0
```

and the controls, so a reader can tell a release's zero from a broken reader:

```
... | grep -c '^class<TAB>MPNowPlayingInfoCenter<TAB>'   # 1 at 6.1.3, 0 at 4.3
```

`grep -c '^class<TAB>…'` is written with the literal tab because a reader who types a space gets a count of
0 for **every** class and would conclude the whole release is empty — which is the same failure mode as the
sign-prefixed selector columns `WholeCacheRead.md` records, where a broken test answered NO to everything and
passed.

## The corpus-level number this band moved

Of the 78 rows this file held at the start, 26 named a measurement. It now holds 42, and **every** row in it
names one — the 42 being the ones this band could not move, each now carrying its own command. The 36 that
left the file are in five new registry files, every one `implemented` and every one citing a measurement
rather than a header.
