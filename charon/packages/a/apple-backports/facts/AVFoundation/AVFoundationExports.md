# AVFoundation names the release already exports

The SDK dates some AVFoundation constants after iOS 6, and asked one by one with `dlsym` after every
framework of the release was loaded, iOS 6 exports fourteen of them. They are the release's own and are not
carried here, and the registry says so where an earlier record had them absent.

Source: an iPad 2 running 6.1.3 and the iOS 6.0 emulator.

## What the release exports

The five track association types `AVTrackAssociationTypeAudioFallback`, `...ChapterList`,
`...ForcedSubtitlesOnly`, `...SelectionFollower` and `...Timecode`, and the video colour keys and values
`AVVideoColorPropertiesKey`, `AVVideoColorPrimariesKey`, `AVVideoColorPrimaries_ITU_R_709_2`,
`AVVideoColorPrimaries_SMPTE_C`, `AVVideoTransferFunctionKey`, `AVVideoTransferFunction_ITU_R_709_2`,
`AVVideoYCbCrMatrixKey`, `AVVideoYCbCrMatrix_ITU_R_601_4` and `AVVideoYCbCrMatrix_ITU_R_709_2`. What an
`AVAssetWriter` of iOS 6 does with the colour keys was not compared with a newer release: the names are exported,
which is what an application that links against them needs, and nothing more is claimed.

## Since which release

AVFoundation exports the nine video colour keys and values from 5.0 and the five track association types
from 6.0.

The registry's `introduced` is the first release on the armv7 cache ladder (3.1.3 to 10.3.4) whose
library the SDK puts the name in exports it (`dyld.exported_at` with `dyld.sdk_owners`, the measure the gate
takes), not the SDK header's date; 3.1.3 is the lowest rung held, so it means "3.1.3 or earlier". The same pass
gives `kCGColorSpaceDisplayP3` 9.3 as the control, so the ladder does not answer its lowest rung for everything.

## Two classes the release already carries

`AVCompositionTrack` and `AVMutableCompositionTrack` are here for the same reason the fourteen constants
above are, and for the same reason they are `ignored` rather than `implemented`: iOS 6 has both, so there
is nothing to carry, and a backport that defined either would put a second class of that name on the
release that owns it. The registry had no row for either, which is what left
`tests/backports/host/avf-descriptors` with no answer for the rows it asks about them.

Both arrived in iOS 4.0 (`AVCompositionTrack.h:32` and `:76`, `API_AVAILABLE(..., ios(4.0), ...)` in the
iPhoneOS 16.4 SDK), and both are measured present at the band floor:

| class | 6.1.3 armv7 AVFoundation image | own instance methods, 6.0 armv7 | superclass |
| --- | --- | --- | --- |
| `AVCompositionTrack` | `_OBJC_CLASS_$_AVCompositionTrack` and its metaclass | 6 | `AVAssetTrack` (52 of its own) |
| `AVMutableCompositionTrack` | `_OBJC_CLASS_$_AVMutableCompositionTrack` and its metaclass | 19 | `AVCompositionTrack` (6 of its own) |

The class symbols were read out of `~/.charon/dyld/6.1.3/dyld_shared_cache_armv7` with
`tools/cache-extract.lua` (dyld.lua's `extract()`) and that image's own symbol table; the method counts
and the superclasses are from the armv7 class table of 6.0,
`~/.charon/dyld/6.0/classes_armv7.json`, where the same image carries `AVMovieTrack` and `AVMutableMovieTrack`
and `AVMovie` is ABSENT - which is what the absent rows in `absent_AVFoundation.json` record for the 13.0
classes.

What the port has to say about these two classes is the 13.0 members it does not carry, and those are
absent rows: `AVCompositionTrack.formatDescriptionReplacements`, `AVMutableCompositionTrack.replaceFormatDescription:withFormatDescription:`
and `-[AVCompositionTrack associatedTracksOfType:]`. The release's own 19 instance methods are the
alternative, and they are what a caller uses: `insertTimeRange:ofTrack:atTime:error:`, `removeTimeRange:`
and `scaleTimeRange:toDuration:`.
