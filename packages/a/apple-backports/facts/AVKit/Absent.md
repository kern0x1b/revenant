# The absent AVKit rows: what each one rests on, and the command that settles it

Thirteen rows in `registry/AVKit` are `absent`. This page carries the measurement behind each one with
the **command a reader can run and its output beside it**, which is what the queue header asks for: a
`source` that names a measurement and not a command is an assertion.

Every name below was read out of one index of the armv7 shared cache of 6.1.3, or asked of the ladder.
Neither is a whole-cache scan: the index is built once by `tools/cache-index/build.py` and every lookup
below is a read of a few megabytes.

## The two questions, and which one answers what

The header is explicit that a first rung answers PRESENCE, not version: the held set is dense to 12.0
and then has a hole - no 10.0, no 13.0, no 14.0, no 15.0 - so **a 13.0 name answers 16.0**. Three rows
here are 15.0 names and one is 14.2, and every one of them answers 16.0. That is the ladder's shape,
not a disagreement about the SDK, which is why each of those rows cites the surface for its version
and the ladder only for presence.

## The index, and how a reader re-reads it

```
$ zcat ~/.charon/cache-index/6.1.3.names.gz | head -1
# charon-cache-index 2 format=2 order=byte release=6.1.3 arch=armv7 \
  source=$HOME/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
  mtime=1362840566000000000 size=244881694 names=568965
```

The header line is the staleness key: release, architecture, the file it was read from, that file's
mtime and size, and how many names it holds. A second run costs 50 header reads and nothing else.

**Rung 1 - is the name real, and in which held release:**

```
$ xmake l tools/cache-index/first-rung.lua AVInterstitialTimeRange AVRoutePickerView
AVInterstitialTimeRange	16.0
AVRoutePickerView	11.0
```

**Rung 2 - does THIS release carry it** (one pass over the 6.1.3 index; this is the command every
"absent from 6.1.3" below was read with):

```
$ python3 - <<'EOF'
import gzip
n=set(); f=gzip.open('$HOME/.charon/cache-index/6.1.3.names.gz','rb'); f.readline()
for l in f: n.add(l.rstrip(b'\n').decode('utf-8','replace'))
for x in ['AVInterstitialTimeRange','AVRoutePickerView','AVPictureInPictureController',
          'AVPlayerViewController','AVKitErrorDomain','_AVKitErrorDomain','AVKit']:
    print('%-42s %s' % (x, 'YES' if x in n else 'no'))
EOF
AVInterstitialTimeRange                          no
AVRoutePickerView                                no
AVPictureInPictureController                     no
AVPlayerViewController                           no
AVKitErrorDomain                                 no
_AVKitErrorDomain                                no
AVKit                                            no
```

Not one of the seven names this port's AVKit rows are named after is in the release. That is the
release-based half of every `absent` on this page, and it is the half the status means.

## The substrate each absent row was measured against, and what came back

Every "present" below is from the same one-pass command as above, over the same 568965 names.

| row | what the row needs from the release | measured |
| --- | --- | --- |
| `AVInterstitialTimeRange`, `AVPlayerItem.interstitialTimeRanges`, the two `...InterstitialTimeRange:` delegate messages | something that marks interstitials in an item | `interstitialTimeRanges` **absent**, `insertInterstitialTimeRange` **absent**; and `seekableTimeRanges`, `loadedTimeRanges` **present**, which is what makes the absence specific rather than general |
| `AVPlayerItem.externalMetadata` | the item's chapter-and-title store | `timedMetadata` **present**, the name **absent** - one is timed and the other is not |
| `AVPictureInPictureSampleBufferPlaybackDelegate` | a release that asks a sample-buffer layer to play | `AVSampleBufferDisplayLayer` **present**, first rung **6.0**, class and metaclass symbols both there; `AVPictureInPictureController` first rung **9.0** |
| `AVRoutePickerView` | a way to say which route output is in use and which is an alternative | the query is all there - `AVAudioSession`, `currentRoute`, `outputs`, `portName`, `portType`, `routeForCategory:`, `UIActionSheet`, and `AVPlayer`'s `allowsExternalPlayback`, `externalPlaybackActive`, `usesExternalPlaybackWhileExternalScreenIsActive` - and the two that would decide it are not: `isWireless` **absent** (first rung **16.0**), and `AVAudioSessionRouteDescription` names no current output |
| `AVPlayerViewController.showsTimecodes` | a frame rate, because a timecode is a frame count | `timecodeStatus` **absent**, `currentTimeline` **absent** |
| `AVPlayerViewController.allowsVideoFrameAnalysis` | a frame-analysis service | `allowsVideoFrameAnalysis`, `videoFrameAnalysis`, `analyzeVideoFrame`, `AVVideoFrameAnalysis`, `requestVideoFrameAnalysis` **all absent** |
| `AVPictureInPictureVideoCallViewController` | a video call to wrap | no such class (first held rung 16.0), and the port builds no call |
| the two `canStartPictureInPictureAutomaticallyFromInline` rows | - | not a substrate question: see below |

## The one that is a fact about the port, and why the status is still release-based

The two `canStartPictureInPictureAutomaticallyFromInline` rows ask for picture-in-picture to start as
the application leaves the foreground. The release has no such property (ios(14.2)), which is the
half the status means. The other half is a measured fact about this tree, and it is worth stating
plainly because the header warns that a port claim is not an `absent`:

> this port's picture-in-picture is a `UIWindow` the application owns, so it is suspended with the rest
> of the application when the application leaves the foreground.

`facts/AVKit/AVPictureInPictureController.md` carries that in full, under "The wall, measured, not
assumed", with the SpringBoard-side companion it would need. Neither YES nor NO would be true of it:
YES promises what the port cannot do, and NO is false, because starting on the way out is exactly what
it cannot do. The row therefore leaves the accessor undeclared, and `respondsToSelector:` says so.

## The one constant that was measured rather than assumed

`AVKitErrorDomain` is **implemented**, not absent, and it is on this page because the measurement is
the interesting part. The queue header's rule is that **the name is never the value** - measured three
times in this corpus, where `PHLivePhotoShouldRenderAtPlaybackTime` is
`LivePhotoShouldRenderAtPlaybackTime` and `CVPixelBufferVersatileBayerKey_BayerPattern` is
`ProResRAW_BayerPattern`. So the value was read out of Apple's own data rather than copied off the
name.

```
$ xmake lua tools/cache-extract.lua modules ~/.charon/dyld/9.0/dyld_shared_cache_armv7 AVKit .agent-work/avkit9/AVKit
extracted AVKit: 4 segments, 1677 symbols, 51187479 bytes
$ file .agent-work/avkit9/AVKit
.agent-work/avkit9/AVKit: Mach-O dynamically linked shared library arm_v7
$ printf 'AVKitErrorDomain\tp\tp\ts\n' > .agent-work/runs/avkit9-symbols.tsv
$ CHARON_ROOT=$PWD xmake l tools/corpus/cache-value.lua ~/.charon/dyld/9.0/dyld_shared_cache_armv7 .agent-work/runs/avkit9-symbols.tsv
```

Three details a reader needs, because each one is a way to get a wrong answer:

- **`cache-value.lua` takes the C name.** It strips the Mach-O underscore from each export before it
  compares, and adds none, so passing `_AVKitErrorDomain` answers "no image of this cache exports it".
  The header's "C symbols need the leading underscore" is advice for `first-rung.lua`, whose index holds
  both spellings; this reader wants the other one.
- **The 8.0 image is the control for the date.** `AVError.h:19` annotates the constant `ios(9.0)`, and
  8.0's AVKit carries the cstring with no `_AVKitErrorDomain` symbol at all:
  ```
  $ nm .agent-work/avkit8/AVKit | grep -i avkiterror      # (nothing)
  $ strings -a .agent-work/avkit8/AVKit | grep -x AVKitErrorDomain
  AVKitErrorDomain
  ```
  So the name sits in 8.0 as a literal and the constant arrives at 9.0, exactly as the header says.
- **The two `AVKitError` enum cases are not symbols and must not be.** `AVKitErrorUnknown` and
  `AVKitErrorPictureInPictureStartFailed` are compile-time enum cases with no storage, so
  `cache-value.lua` correctly reports them as not exported (a line of dashes). Their VALUES come from the header
  (`AVError.h:29-31`: `-1000` and `-1001`), and the port reports the second one, which is the code its
  own picture-in-picture start failure has.

So the value and the name do coincide here - and that is now a reading rather than a hope, which is
the whole difference the header asks for.

## What is not measured, and is named rather than glossed

- **No device has run any of this.** Nothing on this page came off an iPad 2 or an iPhone 4S. The
  absent rows claim what the *release* does and does not carry, which a cache answers; the implemented
  rows' claims about behaviour are in their own pages, and each of those says what a device pass would
  add.
- **`AVRoutePickerView`'s first attempt was written and deleted.** A view holding a button over the
  real route was implemented, and removed, because 6.1.3 cannot say which output is current: the
  compile failed on `property 'port' not found on object of type 'AVAudioSessionRouteDescription *'`.
  With one output on the device - the built-in one, which is current - the sheet would have been empty,
  and a control that opens an empty sheet is the class that exists and does nothing.
- **No other locale's `localizedName` is measured** for `AVPlaybackSpeed`; that is recorded in
  `facts/AVKit/AVPlaybackSpeed.md`, and the numeric name is computed rather than carried, so it is
  right in any locale.
