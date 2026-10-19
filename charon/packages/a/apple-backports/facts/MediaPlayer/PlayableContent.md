# The playable-content family: the 7.1 objects, the 8.4 context, and the two protocols

Five rows that arrived saying "the class arrived in iOS 7.1, and nothing in iOS 6 does its work or stands
in for it" / "the protocol arrived in iOS 7". That the release carries none of them is measured and true
for all five. It is the whole reason for two of them, and not the reason for the other three — see
"What each row is" below, because the three are the ones that changed.

## The two reads, and their controls

Class-scoped, through `coordination/heavy.sh` in the slow lane, one cache per turn. The commands are the
ones in `LanguageOptions.md`; these are the same two files, read once for the whole band.

| name | 6.1.3 | 4.3 |
| --- | --- | --- |
| `MPPlayableContentManager` | ABSENT | ABSENT |
| `MPContentItem` | ABSENT | ABSENT |
| `MPPlayableContentManagerContext` | ABSENT | ABSENT |
| `MPPlayableContentDataSource` | ABSENT | ABSENT |
| `MPPlayableContentDelegate` | ABSENT | ABSENT |
| `MPNowPlayingInfoCenter` (control) | **PRESENT** | **ABSENT** |
| `MPVolumeView` (control) | PRESENT | PRESENT |

`MPNowPlayingInfoCenter` is what makes the zeros mean something: same reader, same two files, a YES and a
NO. The protocols are read from the same file's 1171 protocol lines, which is the only place a protocol's
absence is visible at all — a per-image `__objc_classlist` read cannot see a protocol.

## What each row is, and why the three classes are not the same as the two protocols

- **`MPContentItem`, `MPPlayableContentManager`, `MPPlayableContentManagerContext`** — `implemented`. New
  classes, so new code that shadows nothing, and each is a value holder or a real object over state the
  release has.
- **`MPPlayableContentDataSource`, `MPPlayableContentDelegate`** — `implemented`, and a protocol is the
  easier case, not the harder one: an application's own class conforms to it and this port declares the
  method signatures the header declares. The tree already takes this shape in
  `registry/MetalPerformanceShadersGraph/graph.json`, whose 13 `charon_` rows are all `implemented`.

## The limit, stated rather than hidden

The header is plain about what the family is for (`MPPlayableContentManager.h:17-21`): the manager
"manages the interactions between a media application and an **external media player interface**", an
application supplies a data source to browse content with and a delegate to relay playback commands to.

The half this port supplies is the **application's** half: it stores the data source and the delegate and
reaches them, and `tests/backports/host/mediaplayeritem/playablecontent.m` exercises exactly that with a
real conforming object — the two `@required` members and the delegate's optional callback, both reached
through the port's manager.

The other half is a car head unit. 6.1.3 has none, and this port does not build one. Every header in this
family names its own replacement — `MP_DEPRECATED("Use CarPlay framework", ios(7.1, 14.0))` — and
`CarPlay` arrived in 14.0.

So the honest effect on the three class rows is: real objects, the app's half wired, and **no system half
exists to call it**. That is the same position `MPRemoteCommandCenter71.m` is in, and the difference is
worth keeping straight. `packages/a/apple-backports/xmake.lua:120` calls the command objects "real,
addressable command objects that never fire" — and there the mechanism above them (`UIEventTypeRemoteControl`)
*does* exist on the release, which is why they fire when the hardware sends one. Here there is no
mechanism at all. The row says "reachable, and nothing on this release calls it" rather than either
"working" or "fabricated", because both of those would be wrong.

## Two values that a plain `@synthesize` would have got wrong

**`MPContentItem.playbackProgress` defaults to `-1.0`, not `0.0`.** The header says so
(`MPContentItem.h:44-45`): "0.0 = not watched/listened/viewed, 1.0 = fully watched/listened/viewed /
Default is -1.0 (no progress indicator shown)". A synthesised `float` ivar is zero-initialised, so an
object built without setting it would read `0.0` — which the header defines as *not watched* — where the
documented default is *no indicator at all*. The ivar is initialised explicitly.

**`MPPlayableContentManagerContext.enforcedContentItemsCount` is `NSIntegerMax`, not `0`.** The header
gives the spelling for "no limit": "Returns NSIntegerMax if the content server will never limit the
number of items". That is this case, so the value is Apple's own for this state. A zero would claim the
opposite — that the server will display no items at all — which is a different and wrong answer.

`enforcedContentTreeDepth` is `0`, and it is the one value here that is **not** a measured state. The
header says "Exceeding this limit will result in a crash", so it is a limit the caller must not exceed
rather than a capability. With no endpoint there is no hierarchy to walk and nothing calls it, and `0`
says the depth allowed is none. A large number would claim a capability that does not exist.

`contentLimitsEnabled` is answered from `contentLimitsEnforced` because the header replaces the first
with the second **at the same availability** (`MP_DEPRECATED_WITH_REPLACEMENT("contentLimitsEnforced",
ios(8.4, 9.0))`) — there is no state in which the two could disagree here.

## The check, and its mutants

`tests/backports/host/mediaplayeritem/playablecontent.m` — 20 checks, 0 failures.

It compiles the port's own sources against an empty stand-in `MediaPlayer/MediaPlayer.h` in
`tests/backports/host/mediaplayeritem/standin/`, and that is load-bearing rather than tidy. **This Mac
has `MPContentItem`**: a first draft let the include resolve to the host's framework and clang reported
twelve `duplicate interface definition for class 'MPContentItem'` errors, which reads as a bug in the
port's source and is actually the check measuring the host. Same reason `MPMediaItemStandin.h` exists.

`NSIndexPath` is declared by the check rather than linked from UIKit, because on this host it is a UIKit
type; the port's object never constructs one — it hands the data source's answers back to the caller.

| mutation | verdict |
| --- | --- |
| `playbackProgress` defaults to `0.0` | `RED playbackProgress defaults to the header's -1.0 … : -1.0` |
| `enforcedContentItemsCount` = `0` | `RED … is the header's own 'never limit' value, not 0: NSIntegerMax` |
| `contentLimitsEnabled` returns `YES` | `RED … agrees with the property that replaced it: both NO` |
| `-endUpdates` allowed to go negative | `RED an unpaired -endUpdates is clamped at 0 … : 0` and `RED so a later balanced pair still reads 1 … : 1` |
| `-reloadData` does not count | `RED and the reload count is visible … : 1` |

**One of those five did not fail at first, and the fix is in the check.** The update-depth clamp was
originally asserted by calling a balanced sequence and printing "balanced" — which passes on a mutant
that lets the depth go negative, because a balanced sequence balances under both spellings. The depth is
now read through `-charonUpdateDepth` and compared at each step, which is what makes the clamp observable.
That is the second time in this band a check that could not fail had to be rewritten rather than kept
(the first is the `languageTag` copy in `LanguageOptions.md`); both are recorded rather than quietly
fixed, because a green check that certifies nothing is the same defect as a swallowed error.

`-charonUpdateDepth` and `-charonReloadCount` are the port's own accessors, not a published API: no SDK
header declares a reload count, and adding a public property for a counter Apple does not publish would
be a wider surface than the header's.

## One object per release, and the 8.4 split

`MPPlayableContentManager71.m` holds the 7.1 API and `MPPlayableContentManagerContext84.m` the 8.4 class.
They are separate files because `band()` places an object in exactly one release and a file exporting both
a 7.1 and an 8.4 member would be one object for two releases. `release-split` reads band points only, so
a file mixing two releases passes it — which is why the split is made here and not checked for.

The manager's `context` property is `readonly` and its type is 8.4, so the 7.1 object returns what was
set and does not build a context. Fabricating one would mean a 7.1 file constructing an 8.4 class.
