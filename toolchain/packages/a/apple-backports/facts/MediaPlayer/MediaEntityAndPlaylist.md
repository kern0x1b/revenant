# MPMediaEntity and MPMediaPlaylist: the members iOS 6.1.3 does not have, over the accessors it does

`facts/MediaPlayer/MPMediaItem.md` records this port's `MPMediaItem`, and
`facts/MediaPlayer/CommandEvents.md` the command-event classes. This file records the four rows of the
MediaPlayer queue that were filed `absent` on the ground that "it arrived in iOS 8.0 / 9.3 / 14.0", and
what they answer instead.

## The claim each one rests on

Every one of these is a **named property key over `-valueForProperty:`**, which is what the 26.2 headers
say they are: each property is declared as a `MPMediaPlaylistProperty*` constant beside a property of the
same name, and `-valueForProperty:` takes that key. So the implementation is not a design decision - it is
the contract, and there is nothing in it to invent.

## What the release has, measured

Read with the deleted mach32 reader from the armv7 shared cache of 6.1.3
(`~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7`, MediaPlayer image at `0x31fe3000`). The reader's own
controls are the deleted mach32 test - class count, `valueForProperty:` found in `MPMediaEntity`'s
**own** list, a nonsense selector absent - 0 failures.

| class | own instance | own class | `-valueForProperty:` |
| --- | --- | --- | --- |
| `MPMediaEntity` | 18 | 1 | yes |
| `MPMediaPlaylist` | 15 | 3 | yes |

**All 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS**, resolved through the
category's own class pointer rather than by its name, and none extends `MPMediaEntity` or
`MPMediaPlaylist`. They land on `UIImage`, `NSObject`, `NSIndexSet`, `UIApplication`, `UIWindow`, `UIView`,
`AVMediaSelectionOption`, `AVPlayerItem`, `NSArray`, `NSMutableArray`, `NSBundle`, `NSOperation`,
`NSOperationQueue`, `ML3Entity`, `ML3Collection`, `ML3Album`, `ML3Artist`, `ML3AlbumArtist`,
`ML3Composer`, `ML3Genre`, `ML3Container`, `ML3Track`, `NSString`, `NSNumber`, `UIDevice`, `AVAsset`,
`UIViewController`, `SSLookupResponse`. So nothing the port adds here can clobber a release accessor, and
nothing in the release clobbers the port's.

The reading that does **not** decide a member is the per-cache selector list. `objectForKeyedSubscript:`
occurs exactly once in the whole 6.1.3 selector universe
(`~/.revenant/dyld/6.1.3/selectors_armv7.txt`, 113981 **distinct names** - it is a list of names, not a
count per class: `dealloc` is on one line, not 433) because a collection class declares it, not
`MPMediaEntity`. That is the trap `MPMediaItem.md:105` records for `albumTrackNumber`, which
`MPAVItem` and `MPMediaQueryNowPlayingItem` declare in the same image. Every one of these four is decided
by the per-class read above, not by the per-cache list.

## The key values are Apple's, and were read

`facts/MediaPlayer/MediaPlayerConstants.md:8-12`: the values were read from Apple's own `MediaPlayer` by
`dlsym` and printed as text and bytes by `tests/backports/host/mediaplayer-constants`. They are **not**
each symbol's name. Ten of the thirteen are dotted `public.*` strings, and
`MPNowPlayingInfoPropertyCurrentLanguageOptions` holds the **singular** form of its name - a
one-character difference a naming convention would have got wrong.

| constant | value | object |
| --- | --- | --- |
| `MPMediaPlaylistPropertyAuthorDisplayName` | `externalVendorDisplayName` | `MediaPlayerConstants93.m` |
| `MPMediaPlaylistPropertyDescriptionText` | `descriptionInfo` | `MediaPlayerConstants93.m` |
| `MPMediaPlaylistPropertyCloudGlobalID` | `cloudGlobalID` | `MediaPlayerConstants82.m` |

Neither of the first two equals the name of its constant or of the property it keys. A key spelled from
the property's name would have been wrong twice.

## What each answers

- **`-[MPMediaEntity objectForKeyedSubscript:]`** returns `-valueForProperty:` on the key as given. A key
  the release has no value for answers nil, which is what the release answers and what the header's
  `nullable` says.
- **`MPMediaPlaylist.authorDisplayName`, `.descriptionText`, `.cloudGlobalID`** return the value under
  Apple's key, **and nil when the value is not an `NSString`**. That last clause is not defensive
  padding. `-valueForProperty:` is typed `id` and the properties are typed `nullable NSString *`. The
  release knows what it stored under those keys; the port cannot, because the release's key-value store
  is not readable from outside. Forwarding a value of the wrong type would hand a caller an object under a
  declaration that says `NSString`, and the crash would arrive at the caller's first message to it. nil is
  the header's own nullability, and a playlist with no author is the case it exists for.
- **`cloudGlobalID` answers nil on 6.1.3, and that is the correct answer, not a stub.** A global ID is
  the identifier a playlist has in the user's iCloud account. 6.1.3 has no iCloud music library:
  `MPMediaPlaylist`'s own 15 are `initWithPersistentID:` (a *local* persistent ID), `-items`, `-count`,
  `-persistentID`, `-valueForProperty:`, `-playlistAttributes`, `-mediaTypes`, `-representativeItem`,
  `-existsInLibrary`, `-isEqual:`, `-encodeWithCoder:`, `-initWithCoder:` and the artwork loader, and the
  image's cloud classes - `MPCloudController`, `MPCloudDownloadButton`, `MPCloudAssetDownloadController` -
  are download machinery for an app's own cache. It is Apple's own key read through Apple's own accessor;
  on a release with an iCloud account to name it, it answers the ID. A `cloudGlobalID` that answered an
  invented string on a device with no cloud would be the failure, not the success.

## Shape

A **category** on each class, not an `@implementation` of it: the release's class is the one that carries
the other own methods. Written as a bare `@implementation MPMediaPlaylist` clang asks for
`-valueForProperty:` and the other 14 and refuses the file;
`MediaPlayer/MediaPickerController+AutomaticPresentation.m` is the same idiom in this family.

One object per release, per `band()`'s own rule: `MPMediaEntity80.m` (8.0), `MPMediaPlaylist93.m` (the two
9.3 members) and `MPMediaPlaylist140.m` (14.0). `MPMediaPlaylist.h` is the reason the third exists as a
file of its own: it declares the **key** at 9.0 and the **property** at 14.0, and
`MediaPlayerConstants.md:4` records the key as measured at **8.2** - one release earlier than the header's
own token, and the reason the constants are two objects and not one.