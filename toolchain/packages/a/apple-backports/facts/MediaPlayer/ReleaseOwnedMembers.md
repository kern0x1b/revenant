# Five rows on four classes: members of classes the 6.1.3 release owns

**Five rows, four classes.** `MPMediaLibrary` contributes two of them — `+authorizationStatus` and
`+requestAuthorization:` — and the other three classes one each. A first draft of this title said "Four"
because the four is the number of **objects** and of **classes**, and the body counted **rows**; the body
was right and the title was not. The two counts are both correct and they are not the same number, so
both are in this first line rather than one being left for the reader to reconcile against the other.

`MPMediaItem.md` records this port's `MPMediaItem`; `CommandEvents.md` the command-event classes;
`MediaEntityAndPlaylist.md` the entity and playlist members; `AbsentRows.md` the rows that stay `absent`.
This file records five rows that are members of a class **the release itself carries** - and that is the
whole difficulty in them, because a port cannot add an ivar to a class it does not own.

| row | release | class | what the release has on it |
| --- | --- | --- | --- |
| `MPNowPlayingInfoCenter.playbackState` | 13.0 | `MPNowPlayingInfoCenter` | 5 own instance, 1 own class |
| `MPMediaPickerController.showsItemsWithProtectedAssets` | 9.2 | `MPMediaPickerController` | 19 own instance, 1 own class |
| `+[MPMediaLibrary authorizationStatus]`, `+requestAuthorization:` | 9.3 | `MPMediaLibrary` | 110 own instance, 23 own class |
| `-[MPMusicPlayerController prepareToPlayWithCompletionHandler:]` | 10.1 | `MPMusicPlayerController` | 64 own instance, 5 own class |

## Every number here is the same two reads

Read with the deleted mach32 reader from the armv7 shared cache of 6.1.3
(`~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7`, MediaPlayer image at `0x31fe3000`); the reader's own
controls are the deleted mach32 test - class count, `valueForProperty:` found in `MPMediaEntity`'s
**own** list, a nonsense selector absent - 0 failures.

- **All 41 of the image's categories were read WITH THE CLASS EACH ONE EXTENDS**, resolved through each
  category's own class pointer. **None extends any of these four classes.** That is what makes each of
  these a safe category and what would be unsafe otherwise: a category that landed on one of them would
  be answering the same selector the release answers.
- The whole-cache selector list `~/.revenant/dyld/6.1.3/selectors_armv7.txt` is **113981 distinct names**,
  not per-class counts. It reads **0** for `showsItemsWithProtectedAssets`, `requestAuthorization:` and
  `prepareToPlayWithCompletionHandler:` - absence from the whole release - and **1** each for
  `playbackState` and `authorizationStatus`, because other frameworks declare those names. Where it reads
  1 it decides nothing; the per-class read does. That is the trap `MPMediaItem.md:105` records for
  `albumTrackNumber`, and it is the reason all five rows cite the per-class read first.

## Storage: associated objects, because a category cannot add an ivar

Each of these is a **category** on a class the release owns. The release's `MPNowPlayingInfoCenter` is the
one that carries `-nowPlayingInfo` and `+defaultCenter`; redeclaring it in this tree to add storage would
change a class the release defines, which is undefined behaviour and not something a port may do.

`objc_setAssociatedObject` is public API, and it is what this tree already does for the same problem -
`WebKit/WKWebpagePreferences13.m:39-42` and `SensorKit/SRSensorReader.m:120-135`. Each stored property
gets its own `static const void *` address, as WebKit does, so two properties cannot share a slot and no
selector this port does not define is registered anywhere. The value a caller sets is the value that reads
back, and it is released with the object.

## The defaults, and where each comes from

- **`playbackState` unset answers `MPNowPlayingPlaybackStateUnknown`.** The enum has no other zero:
  `MPNowPlayingInfoCenter.h:44` gives `Unknown = 0`, then `Playing`, `Paused`, `Stopped`, `Interrupted`.
  `Unknown` is the SDK's own name for "the system does not know", which is the state of a release whose
  centre has no way to be told one: 6.1.3's five own methods take a dictionary and never a state.
- **`showsItemsWithProtectedAssets` unset answers `YES`.** The header says so - `// default is YES` - so
  this is Apple's value and not a choice. FairPlay protected assets arrived with iTunes Match, which is
  iOS 7, so on 6.1.3 there is no protected asset for the flag to be about: the flag round-trips what the
  app set and no item is ever filtered, because there is none.
- **`authorizationStatus` answers `Authorized`, and this is the constant a reviewer should check hardest.**
  `MPMediaLibrary`'s own 23 class methods include `+defaultMediaLibrary` and **nothing that refuses** -
  there is no prompt, no restriction object, no `-authorizationStatus`, no `-requestAuthorization:` anywhere
  in its 110 instance methods or the image's 236 classes. "Media & Apple Music Restrictions" is a **7.0**
  Settings pane and this release has none. Of the enum's four cases, `NotDetermined` claims a prompt exists
  (and it is the enum's zero, which is why answering it would be the easy wrong answer), `Denied` and
  `Restricted` claim a refusal there was none of, and `Authorized` is the device's measured state.
  `+requestAuthorization:` hands its handler the same value, and only when the caller supplied one.
- **`prepareToPlayWithCompletionHandler:` answers its handler `nil`.** Apple's signature is
  `(void (^)(NSError *_Nullable error))`; the release's own is `-prepareToPlay`, which returns **void**.
  So the port cannot report a failure it is never told about, and `nil` is Apple's own spelling of
  success. **The limit, stated rather than hidden:** on a queue the release fails to prepare, this answers
  `nil` where Apple's would answer an error. There is no public way to learn that on this release, and
  synthesising one from `-playbackState` would be inventing a failure Apple's own accessor never reports.

## The one that is not a stored value

`MPMusicPlayerController` is the one member here with something to *do*: it calls the release's own
`-prepareToPlay` and then answers the handler. The call goes through `objc_msgSend` with
`sel_registerName("prepareToPlay")` rather than a message expression, for two reasons the file states -
the selector lives in the device's runtime table, not in any header this port compiles against, and ARC
forbids sending through a typed pointer whose type is not the method's own. That is the idiom
`MPRemoteCommandCenter71.m` already uses in this family.

## Shape

One object per release, per `band()`'s own rule: `MPNowPlayingInfoCenter130.m` (13.0),
`MPMediaPickerController92.m` (9.2), `MPMediaLibrary93.m` (the 9.3 pair), `MPMusicPlayerController101.m`
(10.1). Each file holds exactly one release's API, and each is a category, so no file claims a class the
release defines.