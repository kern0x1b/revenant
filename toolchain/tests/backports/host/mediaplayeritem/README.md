# MPMediaItem and the command events: the port's own contract, and what this Mac's MediaPlayer answers

`run.sh` runs four things, in this order: `probe.m` (below -- what the **host's** MediaPlayer answers for
the 22 absent properties), and then the four contract checks -- `contract.m`,
`mpratingcommandeventcheck.m`, `mpskipintervalcommandeventcheck.m` and `mpseekcommandeventcheck.m` -- which
measure the **port's** code. They compile against `packages/frameworks/apple-backports/MediaPlayer` and this
directory's `standin/`, never against this Mac's MediaPlayer, which declares several of these already and
would make a category look like a clobber. Before 2026-10-03 the four checks were in this directory and
named by no runner; `coordination/crutches.md` recorded that, and it is closed.

## The seek check's mutation, and why `mutate.lua` cannot make it

`MPSeekCommandEvent`'s `type` is `@synthesize`d onto its own ivar and has no written getter, so there is
no `return _type;` for `mutate.lua` to substitute -- it prints
`does not contain 'return _type;', so this is not a mutation of the port's code`, which is the tool
refusing correctly. The mutant used instead replaces `@synthesize type = _type;` in a scratch copy with
that line plus an explicit `-type` answering `MPSeekCommandEventTypeEndSeeking`. That changes the bytes
*and* the behaviour, and the check's verdict moves:

    ok   type reads back EndSeeking: EndSeeking
    RED  type reads back BeginSeeking: EndSeeking
    RED  an event nothing set answers the type's zero: EndSeeking
    mpseekcommandevent: 2 RED

The 22 properties the registry declares absent, asked of the host's own framework, with the getter names
read out of the **iOS** SDK header, which is the authority for what exists. Five of them are declared with a
`getter=` attribute, so the property name is not a selector on any platform and a probe that asks for it
learns nothing about them.

    sh run.sh /path/to/iPhoneOS26.2.sdk/.../MediaPlayer.framework/Headers/MPMediaItem.h

## The run

    header: MPMediaItem.h, 22 properties parsed, every getter an identifier
    asked 22, the host declares 22
    control, positive albumTitle            declared
    control, negative aGetterNoFrameworkHas  absent, as it must be

**All 22 getters are declared by the host's own MediaPlayer**, including the five the header writes as
`isExplicitItem`, `isCompilation`, `isCloudItem`, `hasProtectedAsset` and `isPreorder`. So there is no getter
the iOS header declares and the host does not answer, which leaves this family with **no absent candidate
at all** - and nothing for the release cache to be asked, because a check answers a question and there is
none.

A value needs a media library and this process has none, so what the probe asks is what a value cannot: is
the accessor declared, and what does its absence answer. The host answers `nil` through both
`valueForProperty:` and every object-returning getter on a nil receiver, which is the mapping the properties
are - a convenience over the item's own property dictionary under the identically named key.

The types, as the header declares them, which is what a backport returns:

| type | count | properties |
| --- | --- | --- |
| MPMediaEntityPersistentID | 6 | albumPersistentID, artistPersistentID, albumArtistPersistentID, genrePersistentID, composerPersistentID, podcastPersistentID |
| NSUInteger | 5 | albumTrackNumber, albumTrackCount, discNumber, discCount, beatsPerMinute |
| BOOL | 5 | isExplicitItem, isCompilation, isCloudItem, hasProtectedAsset, isPreorder |
| NSString * | 4 | lyrics, comments, userGrouping, playbackStoreID |
| NSURL * | 1 | assetURL |
| NSDate * | 1 | dateAdded |

All readonly, so getters only.

## What this probe got wrong, and what now stops it

1. It asked for the **property name**, where the header writes a `getter=` for five of them - so those names
   are not selectors on any platform. It reads the header now.
2. It compared the availability token for equality against `MP_API` while the header writes
   `MP_API(ios(8.0))` as one token, so it **asked about nothing**, with its controls passing.
3. It kept the header's punctuation, so six pointer-typed properties and four `getter=` ones were asked under
   names that are not selectors, and it printed `asked 16, the host declares 11` as if that were a finding.

(2) and (3) were both caught the same way: **a compile that failed while a stale binary was still on disk**,
its output read as this one's. `run.sh` removes the binary before building and stops on a failed compile, so
a failed build cannot be read as a result. The probe also **asserts** that it parsed all 22 and that every
getter is an identifier - no `*`, no `)`, no `=` - and exits non-zero naming the offender rather than
printing a number.

## The 6.1.3 cache, and what its numbers do not mean

The whole-cache selector list for 6.1.3 (`~/.revenant/dyld/6.1.3/selectors_armv7.txt`, 113981 entries) contains
**10 of the 22** names: albumTrackNumber, albumTrackCount, discNumber, discCount, lyrics, isCompilation,
comments, assetURL, dateAdded, isPreorder. Both controls hold - `prepareToPlay` found, a nonsense name absent.

**That is not a finding about MediaPlayer.** The list is per *cache*, not per framework, and four of those ten
are names any framework may declare (`comments`, `assetURL`, `lyrics`, `dateAdded`). A match is necessary
and not sufficient: a per-framework check against 6.1.3's MediaPlayer image is needed before any of the ten
is written down as something the device release has. That is the next measurement, not this one.

## What 6.1.3's own MediaPlayer has, per class — the measurement the implementation rests on

Read with the mach32 reader (removed) from the 6.1.3 cache (see its test for the controls; the cross-check
that owes the reader nothing: `valueForProperty:` present in the cache 26 times, `dealloc` 433, a nonsense
selector 0). 236 classes in `__objc_classlist`, 41 in `__objc_catlist`.

The class cluster, which is why a control that looked only at `MPMediaItem` failed:

    MPMediaItem          superclass MPMediaEntity        own instance 75  own class  7
    MPMediaEntity        superclass NSObject             own instance 18  own class  1
    MPConcreteMediaItem  superclass MPMediaItem          own instance 29  own class  3
    MPConcreteMediaItemCollection  MPMediaItemCollection  own instance 19  own class 0
    MPNondurableMediaItem          MPMediaItem            own instance 19  own class  2

`valueForProperty:` is an **own** instance method of the public `MPMediaEntity`, alongside
`valuesForProperties:`, `mediaLibrary`, `representativeItem`, `enumerateValuesForProperties:usingBlock:`,
`persistentID`, `copyWithZone:`, `isEqual:` and `hash` — the property-dictionary accessors the 22 properties
are conveniences over.

**None of the 22 getters is anywhere in the release**: not in `MPMediaItem`'s 75, not in
`MPMediaEntity`'s 18, not in `MPConcreteMediaItem`'s 29, and not in any of the 41 categories. So all 22 are
carried, and none is a clobber.

| getter | public own | concrete own | categories | verdict |
| --- | --- | --- | --- | --- |
| albumTrackNumber, discNumber (7.0) | - | - | - | carry |
| albumPersistentID, artistPersistentID, albumArtistPersistentID, genrePersistentID, composerPersistentID, podcastPersistentID, albumTrackCount, discCount, beatsPerMinute, isCompilation, isCloudItem, lyrics, comments, assetURL, userGrouping (8.0) | - | - | - | carry |
| hasProtectedAsset (9.2) | - | - | - | carry |
| dateAdded, isExplicitItem (10.0) | - | - | - | carry |
| playbackStoreID, isPreorder (10.3) | - | - | - | carry |

`albumTrackNumber` is declared by `MPAVItem` and `MPMediaQueryNowPlayingItem` in the same image; neither
is an `MPMediaItem` accessor, and the per-cache selector search had been right that the string exists while
the per-class walk, before the name mask came off, was not.
