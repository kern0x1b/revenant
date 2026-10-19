# iOS 10's AVFoundation rows on 6.1.3: the 36 that `absent_AVFoundation.json` places at 10.0, 10.2 and 10.3

Read class by class, with the reader certified on every release it was run against.

## The reader, and its control on every release

```
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/6.1.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-6.1.3.tsv                      # 12549 lines
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/4.3/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-4.3.tsv                         #  7751 lines
CHARON_ROOT=$PWD xmake l tools/corpus/objc-inventory.lua ~/.charon/dyld/7.0/dyld_shared_cache_armv7 \
    > .agent-work/runs/wav/inv-7.0.tsv                          # 16492 lines
# the removed class-scoped row read, arguments: \
    $HOME/Git/projects/ios/coordination/corpus/queue/SLICE-AVFoundation-absent_AVFoundation-10.tsv \
    6.1.3=.agent-work/runs/wav/inv-6.1.3.tsv 4.3=.agent-work/runs/wav/inv-4.3.tsv \
    7.0=.agent-work/runs/wav/inv-7.0.tsv
```

Its three controls, on all three releases, from the first nine lines of that run's output:
`-[AVPlayerItem duration]` CARRIED, `-[AVPlayerItem aSelectorNoFrameworkHas]` ABSENT,
`-[AVCompositionTrack mediaType]` INHERITED - all three as wanted on 6.1.3, on 4.3 and on 7.0.

Every row of the slice reads ABSENT, NO CLASS or NO PROTOCOL on 6.1.3, so none of the 36 is the
release's own and `check_registry`'s `held` arm cannot fire on any of them at any status.

The 6.1.3 class tables the three forwards were read out of:

| class on 6.1.3 armv7 | own instance | own class | the row needs |
| --- | --- | --- | --- |
| `AVPlayer` | 140 | 19 | `-setRate:`, which begins playback at the rate it is given |
| `AVPlayerItemVideoOutput` | 23 | 0 | `-initWithPixelBufferAttributes:`, AVPlayerItemOutput.h:179 |
| `AVPlayerItem` | 237 | 35 | `-forwardPlaybackEndTime`, `-stepByCount:`, `+playerItemWithAsset:` |
| `AVQueuePlayer` | 15 | 4 | `-insertItem:afterItem:`, `-canInsertItem:afterItem:`, `-items` |

## What the two forwards are, in the SDK's own words

`-[AVPlayer playImmediatelyAtRate:]` - AVPlayer.h:307: "Immediately plays the available media data at
the specified rate ... this method causes the value of rate to change to the specified rate ... and the
receiver to play the available media immediately". A non-zero rate on a player that is not playing is
what begins playback on this release, so the method is the release's own `-setRate:`.

`-[AVPlayerItemVideoOutput initWithOutputSettings:]` - AVPlayerItemOutput.h:185: the argument is "the
client requirements for output CVPixelBuffers, expressed using the constants in AVVideoSettings.h".
Those constants are the pixel buffer attributes, and the ones this release can name were checked one by
one with `first-rung.lua`:

```
_kCVPixelBufferPixelFormatTypeKey    3.0
_kCVPixelBufferIOSurfacePropertiesKey 3.0
_AVVideoWidthKey                     4.0
_AVVideoHeightKey                    4.0
_AVVideoCodecKey                     4.0
_AVVideoCodecTypeH264               11.0
```

The codec names are the one thing that cannot be mapped here: `_AVVideoCodecTypeH264` reads 11.0, so
there is no codec-to-pixel-format table on this release and a settings dictionary that names only a
codec gets the release's own default pixel format from `-initWithPixelBufferAttributes: nil`.

## What the colour properties and the stalling flag are blocked on

`AVVideoComposition.colorPrimaries`, `.colorYCbCrMatrix` and `.colorTransferFunction`, and the same
three on `AVMutableVideoComposition`, are `inert`: 6.1.3's `AVVideoComposition` carries 26 own
instance methods and no colour member, so the colour of a composition on this release comes from the
track's own format description. The value is stored and read back and nothing on this release reads it.

`AVPlayer.automaticallyWaitsToMinimizeStalling` is `inert` for the same shape of reason: the release's
`-play` has the waiting behaviour already and no member reads the flag.

## The two rows whose type does not exist on this release at all

```
$ printf '%s\n' _AVPlayerTimeControlStatusPlaying _AVPlayerItemStatusReadyToPlay \
    _AVCaptureColorSpaceSRGB _AVCaptureColorSpaceP3_D65 _AVMediaCharacteristicIsDefault \
    _AVTrackAssociationTypeTimecode _UTTypeMPEG4Movie _NSURLSession \
    | xmake l tools/cache-index/first-rung.lua
_AVPlayerTimeControlStatusPlaying   NONE
_AVPlayerItemStatusReadyToPlay       NONE
_AVCaptureColorSpaceSRGB             NONE
_AVCaptureColorSpaceP3_D65           NONE
_AVMediaCharacteristicIsDefault      NONE
_AVTrackAssociationTypeTimecode       6.0
_UTTypeMPEG4Movie                   16.0
_NSURLSession                         NONE
```

`AVPlayer.timeControlStatus` and `AVPlayer.reasonForWaitingToPlay` answer in terms of those two
enumerations, which no held release exports, and the enumerations are not rows of this slice either, so
a value this band could produce would be one no caller could compare against its own copy.

The wide-colour rows (`AVCaptureDevice.activeColorSpace`, `AVCaptureDeviceFormat.supportedColorSpaces`,
`AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor`) are the same: `_AVCaptureColorSpaceSRGB`
and `_AVCaptureColorSpaceP3_D65` read NONE, so the colour spaces this row's type names do not exist here.

## `AVPlayerItem.preferredForwardBufferDuration`

The release's own read-ahead members are on its class table - `-bufferingTargetMaximum`,
`-setBufferingTargetMaximum:`, `-limitReadAhead` and `-setLimitReadAhead:` among the 237 - and none of
them is declared in the 16.4 SDK any more, so a category cannot reach one of them and there is no other
member on 6.1.3 whose value is a forward-buffer duration. That is why this row is `absent` and not a
forward: it is not that the mechanism is missing from the release, it is that no header declares it.

## AVPlayerLooper, and why its row is left alone

The class is not on 6.1.3 (`NO CLASS`, and first-rung answers NONE for `_AVPlayerLooper`), and the
release has the mechanism: `AVQueuePlayer`'s `-insertItem:afterItem:` and `AVPlayerItem`'s
`-forwardPlaybackEndTime` are both there, and AVPlayerLooper.h:53 says a replica's range "will be
accomplished by seeking to range start time and setting AVPlayerItem's forwardPlaybackEndTime property on
the looping item replicas". So the release does have what the class is made of, and this row is left
untouched for the coordinator: the class's whole contract is its members - `-status`, `-error`,
`-loopCount`, `-loopingPlayerItems`, `-templateItem`, `-disableLooping` and the three factories - and
none of them is a row of this slice, so a class defined here would be a shell that allocates and does
nothing, which is the one thing the class row must not be.

## What was not verified here

No band build and no 6.1.3 gate was run; the only build this worktree may run is the light guard, which
is green. The objects were compiled on their own with the shared `llvm` package's clang at
`-target armv7-apple-ios6.0 -isysroot` the 16.4 SDK with the flags `modules/apple/backports.lua`'s
`compile_arguments` uses, and every symbol they reference was checked against 6.1.3 with
`first-rung.lua`. Whether a band links them is not verified.