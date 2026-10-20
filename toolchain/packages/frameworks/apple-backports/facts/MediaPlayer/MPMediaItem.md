# MPMediaItem

The properties Apple documents as conveniences over the item's property dictionary. Each row quotes the
26.2 header line it implements, which is also what decides its release group.

## 7.0 — `MPMediaItem70.m`

    @property (nonatomic, readonly) NSUInteger albumTrackNumber MP_API(ios(7.0));
    @property (nonatomic, readonly) NSUInteger discNumber MP_API(ios(7.0));

What 6.1.3 has, measured with the deleted mach32 reader against the 6.1.3 cache (its test carries the
controls; the reader-independent cross-check: the selector strings are present in the cache 26 times,
`dealloc` 433, a nonsense selector 0):

- `albumTrackNumber` — **not declared** by any of the image's 236 classes in their own instance lists,
  and not in any of its 41 categories. Not on `MPMediaItem` (75 own methods), not on `MPMediaEntity`
  (18), not on `MPConcreteMediaItem` (29), the private class a real item's receiver is.
- `discNumber` — the same: nowhere.
- The accessors they are conveniences over **are** present: `valueForProperty:` is an own method of the
  public `MPMediaEntity`, with `valuesForProperties:`, `mediaLibrary`, `representativeItem`,
  `enumerateValuesForProperties:usingBlock:`, `persistentID`, `copyWithZone:`, `isEqual:` and `hash`.

So the registry semantic for both is **the release does not carry it at all** — zero hits in any class
and zero in any category — and both are carried. Adding them as a category on the public class is safe in
both directions: a real item's concrete class implements nothing here, so nothing is clobbered, and a
port-created item answers from its own dictionary.

Contract, in `tests/backports/host/mediaplayeritem/contract.m`: the port's own source compiled against a
stand-in that answers `valueForProperty:`, checking a present key, a missing key (nil, so 0) and the
header's conversion, with a wrong-key and a wrong-conversion mutant each shown red.
<!-- generated: 70 -->

## 7.0 - `MPMediaItem70.m`

The 2 members the 26.2 header declares `MP_API(ios(7.0))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:

    @property (nonatomic, readonly) NSUInteger albumTrackNumber MP_API(ios(7.0));
    @property (nonatomic, readonly) NSUInteger discNumber MP_API(ios(7.0));

Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.
<!-- /generated: 70 -->
<!-- generated: 80 -->

## 8.0 - `MPMediaItem80.m`

The 15 members the 26.2 header declares `MP_API(ios(8.0))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:

    @property (nonatomic, readonly) MPMediaEntityPersistentID albumPersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) MPMediaEntityPersistentID artistPersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) MPMediaEntityPersistentID albumArtistPersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) MPMediaEntityPersistentID genrePersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) MPMediaEntityPersistentID composerPersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) MPMediaEntityPersistentID podcastPersistentID MP_API(ios(8.0));
    @property (nonatomic, readonly) NSUInteger albumTrackCount MP_API(ios(8.0));
    @property (nonatomic, readonly) NSUInteger discCount MP_API(ios(8.0));
    @property (nonatomic, readonly) NSUInteger beatsPerMinute MP_API(ios(8.0));
    @property (nonatomic, readonly, getter = isCompilation) BOOL compilation MP_API(ios(8.0));
    @property (nonatomic, readonly, getter = isCloudItem) BOOL cloudItem MP_API(ios(8.0));
    @property (nonatomic, readonly) NSString * lyrics MP_API(ios(8.0));
    @property (nonatomic, readonly) NSString * comments MP_API(ios(8.0));
    @property (nonatomic, readonly) NSString * userGrouping MP_API(ios(8.0));
    @property (nonatomic, readonly) NSURL * assetURL MP_API(ios(8.0));

Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.

Declared with a `getter=` attribute, so the property name is not the selector: `compilation` is implemented as `isCompilation`, `cloudItem` is implemented as `isCloudItem`.
<!-- /generated: 80 -->
<!-- generated: 92 -->

## 9.2 - `MPMediaItem92.m`

The 1 members the 26.2 header declares `MP_API(ios(9.2))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:

    @property (nonatomic, readonly, getter = hasProtectedAsset) BOOL protectedAsset MP_API(ios(9.2));

Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.

Declared with a `getter=` attribute, so the property name is not the selector: `protectedAsset` is implemented as `hasProtectedAsset`.
<!-- /generated: 92 -->
<!-- generated: 100 -->

## 10.0 - `MPMediaItem100.m`

The 2 members the 26.2 header declares `MP_API(ios(10.0))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:

    @property (nonatomic, readonly) NSDate * dateAdded MP_API(ios(10.0));
    @property (nonatomic, readonly, getter = isExplicitItem) BOOL explicitItem MP_API(ios(10.0));

Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.

Declared with a `getter=` attribute, so the property name is not the selector: `explicitItem` is implemented as `isExplicitItem`.
<!-- /generated: 100 -->
<!-- generated: 103 -->

## 10.3 - `MPMediaItem103.m`

The 2 members the 26.2 header declares `MP_API(ios(10.3))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:

    @property (nonatomic, readonly) NSString * playbackStoreID MP_API(ios(10.3));
    @property (nonatomic, readonly, getter = isPreorder) BOOL preorder MP_API(ios(10.3));

Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.

Declared with a `getter=` attribute, so the property name is not the selector: `preorder` is implemented as `isPreorder`.
<!-- /generated: 103 -->
<!-- generated: 145 -->

## 14.5 - `MPMediaItem145.m`

The 0 members the 26.2 header declares `MP_API(ios(14.5))`, generated from the one list in
`tests/backports/host/mediaplayeritem/generate.lua` together with the getters and the check's table:



Each member's dictionary key is the property's own name, which is the documented convention for
MPMediaItem's property constants and the only reading the header's spelling supports. It is **not**
verified against a populated item, because neither this Mac nor 6.1.3 can be given one without a
media library; what *is* measured is that the release carries none of these members, so a
port-created item - one built from a dictionary, which is exactly what the stand-in in the contract
check is - is the only thing that can answer them here.
<!-- /generated: 145 -->

## 10.0 - `MPMediaItemArtwork100.m`

    - (instancetype)initWithBoundsSize:(CGSize)boundsSize requestHandler:(UIImage *(^)(CGSize size))requestHandler MP_API(ios(10.0));

What 6.1.3 has, measured with the deleted mach32 reader and a negative control (a selector no framework
has is absent): `MPMediaItemArtwork` declares 13 own instance methods - `initWithImage:`,
`imageWithSize:`, `imageWithSize:atPlaybackTime:`, `imageDataWithSize:atPlaybackTime:`,
`coverFlowImageWithSize:`, `albumImageWithSize:`, `albumImageDataWithSize:`, `hasArtworkAvailable`,
`imageCropRect`, `bounds`, `_internal`, `set_internal:`, `dealloc` - and **not**
`initWithBoundsSize:requestHandler:`. A genuine gap.

The release declares `imageWithSize:` on `MPMediaItemArtwork` itself, so a category implementing it
would be shadowed by the release's own method on the release's class and would never run. The
initialiser is therefore a category method - nothing to shadow, the release has no such method -
whose implementation **discards `self` and returns an instance of `RevenantHandlerMediaItemArtwork`**, a
port subclass that stores the bounds and the handler and overrides `imageWithSize:` and `bounds`. A
subclass override is not shadowing: real artwork is an `MPConcreteMediaItemArtwork` and is untouched,
and only artwork a caller made through this initialiser consults the handler, which is what the
header describes. `isKindOfClass:` is true of `MPMediaItemArtwork` for the result, and the concrete
class is a port subclass.

Contract, in `tests/backports/host/mediaplayeritem/artwork.m`, with a handler that records the size it
was asked for:

    ok   the initialiser answers a kind of the class it is called on: an MPMediaItemArtwork
    ok   imageWithSize: returns what the handler returned: the handler's image
    ok   the handler was asked for the size the caller wanted: 300x150
    ok   bounds is the size the initialiser was given: 120x60
    artwork: OK (0 failures)

and the mutant that ignores the handler is red for both reasons it should be:

    RED  imageWithSize: returns what the handler returned: the handler's image
    RED  the handler was asked for the size the caller wanted: other
    artwork: 2 RED

## What the 26.2 header declares that no row covers

Counted from clang's JSON AST of MediaPlayer's umbrella, per class: the
`ObjCInterfaceDecl` and every `ObjCCategoryDecl` whose interface is that class,
unioned by member name, against every row the registry holds. Three controls: a
member known to be declared is found (valueForProperty: in 1 class(es)), a name no header
declares is found zero times, and a scratch copy of the AST with one declaration
removed is short by exactly one member.

| class | declared | a row covers | no row |
| --- | ---: | ---: | ---: |
| MPAdTimeRange | 5 | 0 | 5 |
| MPChangeLanguageOptionCommandEvent | 2 | 0 | 2 |
| MPChangePlaybackPositionCommand | 0 | 0 | 0 |
| MPChangePlaybackPositionCommandEvent | 1 | 0 | 1 |
| MPChangePlaybackRateCommand | 2 | 0 | 2 |
| MPChangePlaybackRateCommandEvent | 1 | 0 | 1 |
| MPChangeRepeatModeCommand | 2 | 0 | 2 |
| MPChangeRepeatModeCommandEvent | 2 | 0 | 2 |
| MPChangeShuffleModeCommand | 2 | 0 | 2 |
| MPChangeShuffleModeCommandEvent | 2 | 0 | 2 |
| MPContentItem | 18 | 0 | 18 |
| MPFeedbackCommand | 6 | 0 | 6 |
| MPFeedbackCommandEvent | 1 | 0 | 1 |
| MPMediaEntity | 5 | 1 | 4 |
| MPMediaItem | 42 | 17 | 25 |
| MPMediaItemAnimatedArtwork | 3 | 0 | 3 |
| MPMediaItemArtwork | 7 | 1 | 6 |
| MPMediaItemCollection | 6 | 0 | 6 |
| MPMediaLibrary | 8 | 4 | 4 |
| MPMediaPickerController | 12 | 1 | 11 |
| MPMediaPlaylist | 9 | 6 | 3 |
| MPMediaPlaylistCreationMetadata | 8 | 0 | 8 |
| MPMediaPredicate | 0 | 0 | 0 |
| MPMediaPropertyPredicate | 5 | 0 | 5 |
| MPMediaQuery | 20 | 0 | 20 |
| MPMediaQuerySection | 2 | 0 | 2 |
| MPMovieAccessLog | 3 | 0 | 3 |
| MPMovieAccessLogEvent | 14 | 0 | 14 |
| MPMovieErrorLog | 3 | 0 | 3 |
| MPMovieErrorLogEvent | 7 | 0 | 7 |
| MPMoviePlayerController | 44 | 0 | 44 |
| MPMoviePlayerViewController | 2 | 0 | 2 |
| MPMusicPlayerApplicationController | 1 | 0 | 1 |
| MPMusicPlayerController | 28 | 6 | 22 |
| MPMusicPlayerControllerMutableQueue | 2 | 0 | 2 |
| MPMusicPlayerControllerQueue | 3 | 0 | 3 |
| MPMusicPlayerMediaItemQueueDescriptor | 8 | 0 | 8 |
| MPMusicPlayerPlayParameters | 2 | 0 | 2 |
| MPMusicPlayerPlayParametersQueueDescriptor | 7 | 0 | 7 |
| MPMusicPlayerQueueDescriptor | 2 | 0 | 2 |
| MPMusicPlayerStoreQueueDescriptor | 7 | 0 | 7 |
| MPNowPlayingInfoCenter | 8 | 1 | 7 |
| MPNowPlayingInfoLanguageOption | 8 | 0 | 8 |
| MPNowPlayingInfoLanguageOptionGroup | 4 | 0 | 4 |
| MPNowPlayingSession | 15 | 0 | 15 |
| MPPlayableContentManager | 11 | 0 | 11 |
| MPPlayableContentManagerContext | 5 | 0 | 5 |
| MPRatingCommand | 4 | 0 | 4 |
| MPRatingCommandEvent | 1 | 0 | 1 |
| MPRemoteCommand | 8 | 0 | 8 |
| MPRemoteCommandCenter | 23 | 20 | 3 |
| MPRemoteCommandEvent | 2 | 0 | 2 |
| MPSeekCommandEvent | 1 | 0 | 1 |
| MPSkipIntervalCommand | 2 | 0 | 2 |
| MPSkipIntervalCommandEvent | 1 | 0 | 1 |
| MPTimedMetadata | 5 | 0 | 5 |
| MPVolumeView | 19 | 1 | 18 |

## 9.0 - `MPChangeLanguageOptionCommandEvent90.m`

    @property (nonatomic, readonly) MPNowPlayingInfoLanguageOption *languageOption;
    @property (nonatomic, readonly) MPChangeLanguageOptionSetting setting;

New code over the base `MPRemoteCommandCenter71.m` already carries, and **carried, not absent**: 6.1.3 has
no class whose name holds `CommandEvent` in any of its 236, none of its 41 categories, and a nonsense
selector is absent as the control. A class the release does not have cannot shadow anything, so there is
nothing native for it to be; `absent` is for a member whose answer needs hardware the device lacks, and
none of this family needs any. The base gains `timestamp` beside the `command` it already had, at the
header's `MP_API(ios(7.1))`; this class's two are `MP_API(ios(9.0))`.

The AST says the header declares exactly `languageOption` and `setting` for the class, and the port
declares exactly those and their setters, so a header member the port would not have is **none**.

Contract, in `tests/backports/host/mediaplayeritem/languageoption.m`:

    ok   the event is a kind of the base the port carries: an MPRemoteCommandEvent
    ok   the base's command is what the event was built with: the command
    ok   languageOption reads back what was set: the option
    ok   setting reads back what was set: 3
    languageoption: OK (0 failures)

and the mutant that stops the accessor answering what was set is red:

    RED  languageOption reads back what was set: other
    languageoption: 1 RED

**A first mutant here was not a mutant at all**, and that is worth recording: removing the `@synthesize`
left ARC to synthesise exactly the same property, the check correctly stayed green, and the file *had*
changed. `mutate.lua` gates on the bytes differing, not on the behaviour differing, so it caught the
no-op replacement and not the no-op behaviour. The accessors are written out for that reason - the
header's readonly ones are the port's own code, and mutating them changes what a caller reads.

## 8.0 - `MPChangePlaybackPositionCommandEvent80.m`

    @property (nonatomic, readonly) NSTimeInterval positionTime;

Carried, for the reason the 9.0 event above gives and the same measurement stands on: 6.1.3 has no
class whose name holds `CommandEvent` in any of its 236, none of its 41 categories, nonsense selector
absent. New code over the base the port already carries, so nothing can be shadowed. The AST says the
header declares exactly `positionTime`, the port declares that and its setter, and a header member the
port would not have is **none**.

Contract, in `tests/backports/host/mediaplayeritem/playbackposition.m`:

    ok   the event is a kind of the base the port carries: an MPRemoteCommandEvent
    ok   the base's command is what the event was built with: the command
    ok   positionTime reads back what was set: 42.5
    ok   an event nothing set answers the type's zero: 0
    playbackposition: OK (0 failures)

and the mutant, whose verdict is printed on **both** sides because `mutate.lua` cannot enforce that for
itself (a1d86395a):

    mutated MPChangePlaybackPositionCommandEvent80.m: 'return _positionTime;' -> 'return 0;'
      RED  positionTime reads back what was set: other
      playbackposition: 1 RED
    against the source tree: playbackposition: OK (0 failures)

An earlier version of this check was green with **nothing tested**: writing it by editing a copy of the
9.0 event's check dropped its own assertion, and the two remaining checks passed. That is the same
failure the byte-only `cmp` gate cannot see, and it is why the verdict on both sides is printed above
rather than just the mutated run.

## 7.1 - `MPChangePlaybackRateCommandEvent71.m`

    @property (nonatomic, readonly) float playbackRate;

Carried, on the measurement the two events above rest on: 6.1.3 has no class whose name holds
`CommandEvent` in any of its 236, none of its 41 categories, nonsense selector absent. The AST says the
header declares exactly `playbackRate` for this class, the port declares that and its setter, and a
header member the port would not have is **none**.

    ok   the event is a kind of the base the port carries: an MPRemoteCommandEvent
    ok   the base's command is what the event was built with: the command
    ok   playbackRate reads back what was set: 1.5
    ok   an event nothing set answers the type's zero: 0
    playbackrate: OK (0 failures)

    mutated: 'return _playbackRate;' -> 'return 0;'
      RED  playbackRate reads back what was set: other
      playbackrate: 1 RED
    against the source tree: playbackrate: OK (0 failures)

## 7.1 - `MPSeekCommandEvent`: carried, with no host check yet

    @property (nonatomic, readonly) MPSeekCommandEventType type;

The one member of this family the 7.1 file already carried, so the piece is a status row and a check
rather than new code. The class and its `type` are in
`packages/frameworks/apple-backports/MediaPlayer/MPRemoteCommandCenter71.m`, which the bridge uses to turn an
`UIEventSubtypeRemoteControl*` into a seek event.

**The check is not written, and the reason is in the row.** `MPRemoteCommandCenter71.m` imports the
real `<MediaPlayer/MediaPlayer.h>` and has no `REVENANT_MEDIAPLAYER_STANDIN` seam, so a host check for it
pulls this Mac's own MediaPlayer and collides with the stand-in's declarations - `MPMediaItem` twice and
`MPMediaEntityPersistentID` as a different type. Giving that file the same seam the generated files take
is the next thing, and it is a file stack 15 already merged, so it wants its own review rather than
riding in a status row.
