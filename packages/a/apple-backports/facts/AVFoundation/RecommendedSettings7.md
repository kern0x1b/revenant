# The 7.0 capture and export rows, answered from a live capture and from the release's own members

Four rows of `registry/AVFoundation/absent_AVFoundation.json`, three of them landed here:
`-recommendedAudioSettingsForAssetWriterWithOutputFileType:`,
`-recommendedVideoSettingsForAssetWriterWithOutputFileType:` and
`AVAssetExportSession.metadataItemFilter`. Three objects carry only 7.0 API, and
`tools/cache-index/first-rung.lua` answers 7.0 for every name they carry, so no object mixes releases.

## The ladder

`strings -a` over each held armv7 cache, with `-markAsFinished` (4.3's own member) as the control of the
search itself:

| selector | 4.3 | 6.0 | 6.1.3 | 7.0 | 7.1 | 8.0 | 11.0 arm64 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `markAsFinished` (control) | 1 | 2 | 2 | 3 | 2 | 2 | - |
| `recommendedAudioSettingsForAssetWriterWithOutputFileType:` | 0 | 0 | 0 | 2 | 2 | 2 | 1 |
| `recommendedVideoSettingsForAssetWriterWithOutputFileType:` | 0 | 0 | 0 | 2 | 2 | 2 | 1 |
| `metadataItemFilter`, `setMetadataItemFilter:` | 0 | 0 | 0 | 2 | 2 | 2 | 1 |
| `audioTimePitchAlgorithm` (7.0's, and the guard's subject) | 0 | 0 | 0 | 6 | 6 | 3 | 1 |

6.1.3's AVCaptureAudioDataOutput carries 13 own instance methods and none of them recommends anything.
6.1.3's AVCaptureVideoDataOutput carries 26 own instance methods among which are -videoSettings,
-availableVideoCodecTypes (5.0's) and -availableVideoCVPixelFormatTypes: the settings are reachable there,
one member at a time. 6.1.3's AVAssetExportSession carries 54 own instance methods and 23 own class
methods and its whole metadata surface is -metadata/-setMetadata:.

## What Apple's own class recommends, measured against a live capture on this machine

`tests/backports/host/avf-recommended-settings7`: this machine's own microphone and camera, added to a real
`AVCaptureSession` which is really started - both headers ask for exactly that ("you should configure your
session first, then query the recommended settings", AVCaptureAudioDataOutput.h:115).

| asked | Apple's answer |
| --- | --- |
| audio, unattached output | nil |
| video, unattached output | nil |
| audio, live input, `public.mpeg-4` | `AVFormatIDKey` 1633772320, `AVNumberOfChannelsKey` 1, `AVSampleRateKey` 48000 |
| audio, live input, `com.apple.quicktime-movie` | the same three keys |
| video, live input, both file types | `AVVideoCodecKey` avc1, `AVVideoHeightKey` 1080, `AVVideoWidthKey` 1920 |

**Neither dictionary carries a bit rate**, and neither carries `AVVideoCompressionPropertiesKey`. The
left-over band answered a fourth key, `AVEncoderBitRateKey` of `channels * 64000`, with nothing behind it;
the measured answer for the same live input has three keys and no rate, so the encoder the settings go to
chooses its own - which is what Apple's own recommendation asks it to do.

The codec is not a constant written in the port either: `AVCaptureVideoDataOutput.h:107` ties the
recommendation to AVCaptureMovieFileOutput's own codecs ("For QuickTime movie and ISO file types, the
recommended video settings will produce output comparable to that of AVCaptureMovieFileOutput"), and
`-availableVideoCodecTypes` is that list. Measured on this machine it is `avc1,jpeg`, and the first entry
is the one Apple's own recommendation answers.

The audio format ID is the one measurement a table carries: `'aac '` (1633772320) for both of the file
types Apple's own class was asked, and `AVAssetExportSession`-side the header says the same thing of the
audio recommendation (AVCaptureAudioDataOutput.h:113, "For QuickTime movie and ISO files, the recommended
audio settings will always produce output comparable to that of AVCaptureMovieFileOutput"). The sample
rate and the channel count are read out of the connection's own input port's format description, and the
video dimensions out of the same description, so nothing in either dictionary is a number the port chose.

**One thing the check had to be told, measured:** the concrete class of a capture output on this machine
is `AVCaptureVideoDataOutput_Tundra`, a framework SUBCLASS that carries its own implementation of both
methods, so a message send reaches that and never a category on the public class. The check therefore
calls the port's own IMP, fetched with `class_getInstanceMethod`, and prints both addresses; a run where
they are equal measures nothing and says so.

## The export's filter, and the one hook it has

`AVAssetExportSession.h:383-386`: "Specifies a filter object to be used during export to determine which
metadata items should be transferred from the source asset. If the value of this key is nil, no filter
will be applied. This is the default. The filter will not be applied to metadata set with via the metadata
property."

On this release the only moment the port can act is
`-[AVAssetExportSession exportAsynchronouslyWithCompletionHandler:]` - 6.1.3's own member, present at 4.3
and at 6.0 too - so that is what it interposes on, after the release's own implementation has run. What it
filters with is the release's own entry point,
`+[AVMetadataItem metadataItemsFromArray:filteredByMetadataItemFilter:]`, which the port already carries
(`AVFoundation/AVMetadataItemGroups7.m`) and which `tests/backports/host/avf-metadata` holds against
Apple's own: the wiring is new, the filtering is not re-implemented.

**What a caller sees afterwards is the price of that hook, and it is measured.** Apple's own session writes
the kept items into the OUTPUT FILE and leaves `metadata` nil, measured here on a real export of a real
file. This release has no member that hands the file a list, so the port leaves the filtered items on the
session and lets the release's own export write them. `tests/backports/host/avf-export-metadata-filter7`
holds the port to the exact value: what it leaves on the session must be what the release's own filtering
entry point answers for the source's own array, and the three cases the header names - no filter, a
filter with no metadata of the caller's, and a filter with the caller's own metadata - are three rows.

That check needs a stand-in for the release, because the guard the port installs reads a 7.0 member to ask
whether the release has arrived, and this machine's session has it. The stand-in's expectation is the
measured one: the host half of the same run exports a real file through Apple's own AVFoundation, and the
port half is held both to that table and to the release's own filtering answer. The stand-in is the
control, not the oracle.

## The four rows

| row | what the caller gets |
| --- | --- |
| `-[AVCaptureAudioDataOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:]` | AAC at the live sample rate and channel count, or nil when the output is attached to no session - Apple's own three keys, no fourth |
| `-[AVCaptureVideoDataOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:]` | the release's own first codec at the live frame size, or nil when there is no live format |
| `AVAssetExportSession.metadataItemFilter` | the filter, and at the export's start the release's filtered copy of the source's metadata on the session, unless the caller set metadata of its own |
| `AVPlayerItemAccessLogEvent.startupTime` | **not landed here** - see below |

### The fourth row, and why this page does not carry it

`-[AVPlayerItemAccessLogEvent startupTime]` stays `absent`. The header's definition is "the accumulated
duration, in seconds, from when the item was initialized to when it first became ready to play", which is
a property of the ITEM, and both of its instants are observable: an `AVPlayerItem`'s construction and the
transition of its own `status` to `AVPlayerItemStatusReadyToPlay`. What the port cannot do is put the
number on the object the client will read it from. The release creates that event inside `AVPlayerItem`
when a playback session begins, and the only members that hand it out are `-accessLog` and, on the log,
`-events`; neither is where the event is made. Writing the value from `-events` would mean stamping an
object the port did not create, from a KVO observer the port installs on a release-owned `status`, on
whatever thread that transition arrives - and the row would then be `implemented` on the strength of a
mechanism whose subject is a guess. The left-over band did exactly that (a `-initWithAsset:` interposition,
a KVO timer, and a write to `accessLog.events.firstObject`, which is nil until playback begins, so its
getter answered -1 for every client). The honest end for that row is still the measured `absent` the
registry carries, and its reason is now longer than it was.

## Reproducing

    sh tests/backports/host/avf-recommended-settings7/run.sh                    the differential
    sh tests/backports/host/avf-export-metadata-filter7/run.sh                  the differential

Both need a capture device and, for the first, a running session. Both are the whole measurement: 34 keys
in the first (all agreeing, no key on one side only) and 18 rows in the second (one allowed difference, and
the port's own assertion against the release's filtering answer).