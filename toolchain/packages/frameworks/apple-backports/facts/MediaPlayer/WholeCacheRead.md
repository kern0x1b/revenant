# The whole-cache rung: 6.1.3 read in one pass, 11378 classes and 1171 protocols

Every other page in this folder decides its rows from the MediaPlayer image alone
(the deleted mach32 reader over the image at `0x31fe3000`, 236 classes, 41 categories). That is the right
rung for a member of a MediaPlayer class and it is not enough for two things in this family: a member of a
class MediaPlayer does not own, and a **protocol** — a protocol's absence is a fact about the whole release,
not about one image. This page is the rung that decides those, and it was run once, through
`coordination/heavy.sh`, at a load of 9.08.

```
REVENANT_ROOT=<worktree> xmake l tools/corpus/objc-inventory.lua \
  ~/.revenant/dyld/6.1.3/dyld_shared_cache_armv7 > inventory-6.1.3.tsv
12549 lines: 11378 classes, 1171 protocols
```

The reader's controls, from the same file: a class no framework has reads absent, and `MPVolumeView` and
`MPNowPlayingInfoCenter` read present.

## What it settles that the per-image read could not

**`AVPlayerItem.nowPlayingInfo` (16.0)** — the member of an AVFoundation class, which is why this row
waited two turns for it. In the whole cache, `AVPlayerItem` lives in `AVFoundation.framework/AVFoundation`
with **237 own instance selectors and 35 own class selectors**:

| selector | in AVPlayerItem's own 237 |
| --- | --- |
| `status` | **yes** |
| `timedMetadata` | **yes** |
| `duration` | **yes** |
| `MPAVItem` | **yes** — the MediaPlayer category's own method |
| `nowPlayingInfo` | **no** |
| `setNowPlayingInfo:` | **no** |

One class, one reader, a YES and a NO: that is the control that makes the NO mean something. And across the
**whole** 6.1.3 cache exactly **two** classes declare `nowPlayingInfo` in their own instance list —
`MPNowPlayingInfoCenter` (MediaPlayer) and `MRMediaRemoteState` (`PrivateFrameworks/MediaRemote`, a private
framework no application links). Neither is `AVPlayerItem`.

The release's whole-cache **selector list** could not have decided this, and this is the second time that
rung has had to be passed over in this family: `nowPlayingInfo` is on **one** of its 113981 distinct names,
because some class somewhere declares it. The per-cache list is a list of names, not of owners.

**Twenty class and protocol rows, absent from the whole release** — not merely from MediaPlayer's image,
which is the stronger claim and needs this rung for a protocol:

`MPAdTimeRange`, `MPContentItem`, `MPNowPlayingSession`, `MPNowPlayingSessionDelegate`,
`MPPlayableContentManager`, `MPPlayableContentManagerContext`, `MPPlayableContentDataSource`,
`MPPlayableContentDelegate`, `MPSystemMusicPlayerController`, `MPMusicPlayerQueueDescriptor`,
`MPMusicPlayerMediaItemQueueDescriptor`, `MPMusicPlayerStoreQueueDescriptor`, `MPMusicPlayerPlayParameters`,
`MPMusicPlayerPlayParametersQueueDescriptor`, `MPMusicPlayerControllerQueue`,
`MPMusicPlayerControllerMutableQueue`, `MPMusicPlayerApplicationController`, `MPMediaPlaylistCreationMetadata`,
`MPNowPlayingInfoLanguageOption`, `MPNowPlayingInfoLanguageOptionGroup`.

The twenty is the number of NAMES in that list, and the page that lists them is the only place it appears: eleven
classes and four protocols plus five more classes, all read one at a time against the 12549 lines above. A
first draft of this line said sixteen, which is the number of *rows* in the queue those twenty names come
from once the two `MPMusicPlayerControllerQueue` spellings are counted once — a count nobody could recompute,
in a page whose subject is a reader whose whole value is that its numbers can be.

**Every one is new code that cannot shadow anything**, which is what `implemented` over `absent` needs: the
release has no object of that name, so a port class with that name collides with nothing. The 1171 protocol
rows in the file are what make that true for the four protocol rows — a protocol is not a class, its absence
is not visible to a per-image classlist read, and `MPPlayableContentDataSource` and `MPPlayableContentDelegate`
are rows in this family.

## The band that links the one AVFoundation-owned member, and the framework it needs

`AVPlayerItem.nowPlayingInfo` is carried, and it is the only object in `MediaPlayerBackports` whose owner
class is not MediaPlayer's. That makes it the only one whose **link** needs a framework the library did not
name, and the failure is structural rather than a missing import: a category's class reference is a symbol,
so a band that does not carry `AVFoundation` leaves `_OBJC_CLASS_$_AVPlayerItem` undefined and ld fails with
`Undefined symbols for architecture armv7`.

**What the band links is the library's `frameworks` list in `modules/apple/backports.lua`**, filtered per
release by `framework_install_path()`, which links what the band's own first and last release carry at one
install path and prints a note for what they do not. `MediaPlayerBackports` was declared
`{"MediaPlayer", "UIKit", "Foundation"}` - the release's MediaPlayer is a MediaPlayer class library, and
every other object in the folder is a MediaPlayer or UIKit class. **AVFoundation is now in that list**, which
is what binds the category to the release's own AVPlayerItem: `nm -m` on the linked dylib then reads
`(undefined) external _OBJC_CLASS_$_AVPlayerItem (from AVFoundation)`, a bound two-level namespace import
rather than an unresolvable undefined symbol, and that is the shape `check_categories()` accepts. This is
the tree's existing answer and not a new one: `AVKitBackports` declares `AVFoundation` because its
`AVPictureInPictureController.m` holds an `AVPlayerLayer *` that is AVFoundation's (`6e157ef78`), and
`PhotosBackports` and `CallKitBackports` both declare it for objects of theirs that need it.

**What it costs is nothing, and that is measured rather than assumed.** The band links `-framework
MediaPlayer` on every band, so the release's own MediaPlayer is in the process whatever this list says, and
that image already loads AVFoundation:

```
$ otool -L ~/.revenant/dyld/6.1.3/MediaPlayer
MediaPlayer:
	/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer (compatibility version 1.0.0, current version 1.0.0)
	... 38 of its 39 LC_LOAD_DYLIB entries elided here; AVFoundation and CoreMotion are its last two ...
	/System/Library/Frameworks/AVFoundation.framework/AVFoundation (compatibility version 1.0.0, current version 2.0.0)
	/System/Library/Frameworks/CoreMotion.framework/CoreMotion (compatibility version 1.0.0, current version 1491.92.0)
```

`~/.revenant/dyld/6.1.3/MediaPlayer` is the file 6.1.3 ships **beside** its shared cache - the
`outside_armv7` case `check_band_caches()` names - so this is a read of a release file and not of a cache
image. AVFoundation is one of 39, beside CoreMedia, CoreVideo, CoreGraphics, ImageIO, QuartzCore,
AudioToolbox and MobileCoreServices. So the change is a declaration and not a load: what was missing was the
linker's right to bind `_OBJC_CLASS_$_AVPlayerItem`, not an image.

**What was rejected, and why.** Re-homing the property onto `MPNowPlayingInfoCenter` is a change in
behaviour and not a fix: the declaration is
`@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo` on
`@interface AVPlayerItem (MPAdditions)` in `AVPlayerItem+MPAdditions.h`, MediaPlayer's own header, so a
caller writes `[playerItem setNowPlayingInfo:]` and nothing on `MPNowPlayingInfoCenter` would answer it.
`absent` is also wrong here: the release does not carry the accessor (the table above), but the port can,
and `absent` is reserved for a row the release makes impossible.

## The object that is not checked on the host

`AVPlayerItem+NowPlayingInfo16.m` is the one implemented entry of this folder with no differential test
under `tests/backports/host/mediaplayeritem/`, which `packages/frameworks/apple-backports/README.md` asks of every
implemented entry. `run.sh` there builds `probe.m` alone, and the folder's stand-in tree carries MediaPlayer
and UIKit headers but no AVFoundation one, so the stand-in seam the object uses
(`REVENANT_MEDIAPLAYER_STANDIN`, which no test in this series defines) is never taken. What it would compare
is the port's own accessor pair against the host's `AVPlayerItem.nowPlayingInfo`, which a Mac's AVFoundation
declares already - the same host-is-not-the-measurement problem `MPMediaItemStandin.h:1-5` records for
`MPMediaItem.albumTrackNumber`, and the same answer: a stand-in build, not the host's framework. That is a
separate unit of work from the link this page's first section is about, and it is not done here.

## One correction this rung caught in my own earlier reading

The inventory's selector columns are **sign-prefixed** — `-nowPlayingInfo`, `+sharedCommandCenter` — not
bare names. A first pass tested membership of the bare name and reported `status`, `externalMetadata` and
`timedMetadata` as absent from `AVPlayerItem` too, which is impossible and was the sign of a broken test
rather than a surprising cache. Stripping the sign gives the table above. A reader that answers NO to
everything would have passed the `nowPlayingInfo` check while being wrong about `status`, and the two
together are what caught it.

## What it does not settle, and the rung that does

- **A member of a MediaPlayer class.** The per-image read is better: it resolves each of the 41 categories'
  **own** class pointer, which is the clobber question a whole-cache merge cannot answer.
- **The value of a named key.** Neither rung reads the value of `MPMediaPlaylistPropertySeedItems`, and the
  port's own keys prove a value cannot be spelled from a name
  (`facts/MediaPlayer/MediaPlayerConstants.md:8-12`). That needs `tools/corpus/cache-value.lua` against the release that
  first exports the name — a host differential, which is why `MPMediaPlaylist.seedItems` is still on the
  corpus's blanket reason rather than on this page.
- **Whether a release that gates a library gates it.** `MPMediaLibrary93.m` is measured per-image and says
  so; no cache read can say what a 7.0 device would answer.