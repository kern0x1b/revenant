# Ten MediaPlayer rows that stay `absent`, and what each one's absence is

The 47 rows of `coordination/corpus/queue/MediaPlayer.tsv` all arrived saying "neither iOS 6 nor the
backports give X a property like it: it arrived in iOS N" or "the class arrived in iOS N, and nothing in
iOS 6 does its work or stands in for it". That the release carries nothing is measured and true for every
one of them. It is the **whole** reason only for the ten on this page. The other three-carrying sets are in
`MPMediaItem.md`, `CommandEvents.md` and `MediaEntityAndPlaylist.md`, where the release turns out to have
the accessor the row is a convenience over.

`absent` is for a row whose answer needs a thing the device does not have. Nine of these ten are that. The
tenth is a class that arrived in iOS 8, where a category would compile, link, and never install.

## Every measurement here is the same two reads

Read with the deleted mach32 reader from the armv7 shared cache of 6.1.3
(`~/.charon/dyld/6.1.3/dyld_shared_cache_armv7`, MediaPlayer image at `0x31fe3000`); the reader's own
controls are the deleted mach32 test, 0 failures.

- **236 classes** in `__objc_classlist`, **41** in `__objc_catlist`. All 41 categories were read **with the
  class each one extends**, resolved through the category's own class pointer rather than by its name.
- The whole-cache selector list `~/.charon/dyld/6.1.3/selectors_armv7.txt` is **113981 distinct names** -
  a list of names, not a count per class (`dealloc` is on one line, not 433). A count of 0 there is
  necessary and not sufficient; a count of 1 says some class somewhere declares it. Where a row below turns
  on absence, the per-class read above is the evidence.
- `tools/cache-index/first-rung.lua`, self-test 8 checks 0 failures, answers the oldest **held** release that
  carries a name - presence, not the release that introduced it, and the held set has a hole above 12.0.

## The two MPVolumeView rows are spelled for their getters, not their property names

`MPVolumeView.h` at SDK 26.2:

```
@property (nonatomic, readonly, getter=areWirelessRoutesAvailable) BOOL wirelessRoutesAvailable
    MP_DEPRECATED("Use AVRouteDetector.multipleRoutesDetected instead.", ios(7.0, 13.0))
@property (nonatomic, readonly, getter=isWirelessRouteActive) BOOL wirelessRouteActive
    MP_DEPRECATED("Use AVPlayer.externalPlaybackActive instead.", ios(7.0, 13.0))
```

The `getter=` attribute means **`areWirelessRoutesAvailable` and `isWirelessRouteActive` are the selectors
and neither property name is a selector on any platform**. The rows are re-spelled for the accessors,
which is what `MPMediaItem.md:61` already does for `MPMediaItem.isCompilation` and `:79` for
`MPMediaItem.hasProtectedAsset`, and what the corpus's own property names cannot be used for.

`MPVolumeView` on 6.1.3 has **54 own instance methods and 0 own class methods**, and none of the image's 41
categories extends it. Its AirPlay route *UI* is there - `showsRouteButton`, `setRouteButtonImage:forState:`,
`routeButtonImageForState:`, `routeButtonRectForBounds:`, `_displayAudioRoutePicker`, `_routeButton`,
`routePopoverPermittedArrowDirections:` - but the route state behind those is `MPAudioDeviceController`'s
private tables, and no public API on this release reads it. `AVAudioSession` exists on 6.1.3 (first rung
3.0) and reports the **audio** route; reporting an audio output as "a wireless route is available" would be
a different API's answer under this property's name, which is the failure this port exists to avoid rather
than the success it looks like.

**The port already answered this question once.** `MediaPlayerConstants70.m` carries
`MPVolumeViewWirelessRoutesAvailableDidChangeNotification` and
`MPVolumeViewWirelessRouteActiveDidChangeNotification`, values read from **iOS 7.0's own armv7 cache** with
`tools/corpus/cache-value.lua` and registered `implemented`. Nothing posts either: there is no state whose change is
worth posting. Carrying the properties without a state to read would be the same incompleteness with two
more accessors on top.

## The four Store and cloud rows

| row | what Apple answers | what 6.1.3 has |
| --- | --- | --- |
| `-[MPMediaLibrary addItemWithProductID:completionHandler:]` | the library adds a Store purchase | `MPMediaLibrary`'s own 110 instance and 23 class methods are all local-library work; the selector is on **0** of the 113981 names |
| `-[MPMediaLibrary getPlaylistWithUUID:creationMetadata:completionHandler:]` | find or create a playlist in the user's iCloud account | no iCloud music library on 6.1.3; the image's cloud classes - `MPCloudController`, `MPCloudDownloadButton`, `MPCloudAssetDownloadController` - are an app's own download cache; selector on **0** names |
| `-[MPMediaPlaylist addItemWithProductID:completionHandler:]` | add a Store purchase to a cloud playlist | as above; selector on **0** names |
| `-[MPMediaPlaylist addMediaItems:completionHandler:]` | add items to the playlist's **cloud** copy | `MPMediaPlaylist`'s own 15 methods hold **no mutator at all**: `initWithPersistentID:` (a *local* persistent ID), `-items`, `-count`, `-persistentID`, `-valueForProperty:`, `-playlistAttributes`, `-mediaTypes`, `-representativeItem`, `-existsInLibrary`, `-isEqual:`, `-encodeWithCoder:`, `-initWithCoder:` and the artwork loader; selector on **0** names |

Appending to the local playlist would answer something Apple's own does not, which is the whole point of
the measurement in this family. An implementation that added the items locally would be `implemented` and
wrong.

## `-[MPMusicPlayerController setQueueWithStoreIDs:]`

`MPMusicPlayerController` on 6.1.3 has **64 own instance methods and 5 own class methods**, and none of
them takes a Store ID in any spelling: both `setQueueWithStoreIDs:` and `setQueueWithItemIDs:` are on **0**
of the 113981 names. What the release has is `setQueueWithQuery:`, `setQueueWithItemCollection:`,
`setQueueWithSeedItems:`, `setQueueWithGeniusMixPlaylist:` and `setQueueWithQuery:firstItem:`.

And there is nothing to resolve an ID to. A Store ID is what `MPMediaItem.playbackStoreID` holds; that
property is this port's own 10.3 carry (`registry/MediaPlayer/ios10_3mpitem.json`) reading a property key
the release has no value for - `playbackStoreID` is on **0** of the 113981 names, and `MPMediaItem.md`
records that none of the 22 MPMediaItem getters is declared anywhere in the release. So a store queue on
this device has no items at all, by two independent reads.

## `NSUserActivity.externalMediaContentIdentifier`

The **class** arrived in iOS 8: `first-rung.lua` answers `8.0` for `NSUserActivity` - the oldest held
release that carries the name - and it is not among 6.1.3's 236 classes. `externalMediaContentIdentifier`
is on **0** of the 113981 names.

This row is not `absent` because the answer needs something the device lacks. It is `absent` because a
**category on a class the release does not have compiles, links, and then never installs**: the image
would carry a category nobody can attach, and the row's `effect` sentence - "respondsToSelector: answers
honestly and an unchecked call raises" - would be a claim about a class that does not exist. That is
`ef271700`'s finding D on ARKit, where a conformance-only category made no metadata and the dylib had **0**
occurrences of the name. A row like this is better `absent` than an `implemented` that installs nowhere.

## `MPNowPlayingSession` and `MPNowPlayingSessionDelegate`

6.1.3's MediaPlayer has no session surface at all. No such class among the 236;
`-becomeActiveIfPossibleWithCompletion:` on **0** of the 113981 names; and the object a session exists to
activate is `MPNowPlayingInfoCenter`, whose own 5 instance methods are
`_pushNowPlayingInfoAndRetry:`, `setNowPlayingInfo:`, `nowPlayingInfo`, `_init` and `init`, with one own
class method, `+defaultCenter`.

So `canBecomeActive` has nothing that could answer YES, `active` would be NO on every call, and all eight
declared members would be a fabricated NO or a stored value nothing reads. That is the object's absence in
another name, and the delegate's two callbacks
(`-nowPlayingSessionDidChangeActive:`, `-nowPlayingSessionDidChangeCanBecomeActive:`, the first on **0** of
the 113981 names) describe a session that cannot exist.

The port already carries what iOS 6.1.3 actually offers for the same job: `MPRemoteCommandCenter71.m`
bridges the remote commands onto `UIEventTypeRemoteControl`, and `MediaPlayerConstants70.m` carries the
now-playing keys. A session is the 16.0 shape of that, not a 6.1.3 one.