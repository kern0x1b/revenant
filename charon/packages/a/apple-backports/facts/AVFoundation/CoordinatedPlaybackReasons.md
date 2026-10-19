# The coordinated-playback reasons, the playback-coordinator notifications, the player rate-change keys

19 constants, all of them iOS 15.0, in `packages/a/apple-backports/AVFoundation/CoordinatedPlaybackReasons15.m`.
None of them names a camera, a microphone or a media library: they are the strings one participant
hands another when a coordinated playback session suspends, the two notifications those participants
post, and the keys and reasons a player reports when its rate changes.

## How the values were read

The same measurement as [MetadataKeySpaces.md](MetadataKeySpaces.md), and the same differential: one
`dlsym` of the exported symbol in the host's own AVFoundation per name, printed as text and as
bytes, then the table read out of two builds - Apple's framework alone, and the port's file beside it
in one binary with the names renamed - and diffed. All 19 answered; the port's table is
byte-identical to the host's.

Worth naming because it is the sort of thing a header reading gets wrong by copying the *symbol* for
the *string*: **every one of these values is the symbol's own name.** `AVPlayerRateDidChangeReasonKey`
answers the eleven characters `AVPlayerRateDidChangeReasonKey`; so do the six reason constants and
the two `AVPlayerWaiting...` reasons. That is what the host answered for all 19 of them, and
it is a real answer rather than a placeholder: a participant compares the string it is handed against
these, and the port hands out the same bytes the framework does, so a comparison against the port's
constant and a comparison against Apple's agree.

The two notification names are the same shape, and are what `NSNotificationCenter` observers register
for. A program that observes `AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification` on the
port and one that observes it on a modern device are therefore posting and observing the same name,
which is what makes a cross-release session possible at all.

## The values

| constant | value the host answered | bytes |
| --- | --- | --- |
| `AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted` | "AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted" | 60 |
| `AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible` | "AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible" | 67 |
| `AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial` | "AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial" | 56 |
| `AVCoordinatedPlaybackSuspensionReasonStallRecovery` | "AVCoordinatedPlaybackSuspensionReasonStallRecovery" | 50 |
| `AVCoordinatedPlaybackSuspensionReasonUserActionRequired` | "AVCoordinatedPlaybackSuspensionReasonUserActionRequired" | 55 |
| `AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime` | "AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime" | 62 |
| `AVMetadataIdentifierQuickTimeMetadataIsMontage` | "mdta/com.apple.quicktime.is-montage" | 35 |
| `AVMetadataQuickTimeMetadataKeyIsMontage` | "com.apple.quicktime.is-montage" | 30 |
| `AVPlaybackCoordinatorOtherParticipantsDidChangeNotification` | "AVPlaybackCoordinatorOtherParticipantsDidChangeNotification" | 59 |
| `AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification` | "AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification" | 59 |
| `AVPlayerRateDidChangeNotification` | "AVPlayerRateDidChangeNotification" | 33 |
| `AVPlayerRateDidChangeOriginatingParticipantKey` | "AVPlayerRateDidChangeOriginatingParticipantKey" | 46 |
| `AVPlayerRateDidChangeReasonAppBackgrounded` | "AVPlayerRateDidChangeReasonAppBackgrounded" | 42 |
| `AVPlayerRateDidChangeReasonAudioSessionInterrupted` | "AVPlayerRateDidChangeReasonAudioSessionInterrupted" | 50 |
| `AVPlayerRateDidChangeReasonKey` | "AVPlayerRateDidChangeReasonKey" | 30 |
| `AVPlayerRateDidChangeReasonSetRateCalled` | "AVPlayerRateDidChangeReasonSetRateCalled" | 40 |
| `AVPlayerRateDidChangeReasonSetRateFailed` | "AVPlayerRateDidChangeReasonSetRateFailed" | 40 |
| `AVPlayerWaitingDuringInterstitialEventReason` | "AVPlayerWaitingDuringInterstitialEventReason" | 44 |
| `AVPlayerWaitingForCoordinatedPlaybackReason` | "AVPlayerWaitingForCoordinatedPlaybackReason" | 43 |


## Which release exports each name, and why the objects are split

Measured, not read from a header. `dyld.first_releases` over the armv7/armv7s ladder, and a direct
`tools/corpus/dump-cache.lua` of the exports of the arm64 caches of 9.3.6, 10.0.1, 11.0 and 12.0 and
the arm64e cache of 16.0. **The control: `_NSFileSize` answers 3.0 on the armv7 ladder and 7.0 on the
arm64 one**, so a run that answered nothing for it would be a broken measurement and not an answer of
"no release exports this".

That gives 2 names first exported at **10.0.1**, 5 at **12.0** and 40 at **16.0**. A 12.0 band
therefore already has 7 of the 47, and `band()` (`modules/apple/backports.lua:713-742`) raises
*"an object carries API that arrived in one release, so split it"* on any object that mixes one of
those with a name that band lacks. A single-band 6.1.3 gate does not see it, because `#present` is 0
there - which is why the mechanical verdict was clean and the all-band build would not have been.

So the objects are split by the measurement: the 10.0.1 pair in `MetadataKeyspaces10.m`, the three
12.0 key-space names in `MetadataKeyspaces12.m`, the two 12.0 player rate-change names in
`CoordinatedPlaybackReasons12.m`, and the 40 the 16.0 cache is first to export in the four files their
API generation names. `release-split` is clean over both layouts, and the 12.0 layout holds exactly the
7:

    objects/       clean, every object file's symbols first-appear in one release (7 files, 47 symbols, 50 releases checked)
    objects-12.0/  clean, every object file's symbols first-appear in one release (3 files, 7 symbols, 50 releases checked)

**The registry's `introduced` is corrected for seven rows.** Apple's header annotation is later than
what its own releases export - `AVMetadataIdentifierQuickTimeMetadataIsMontage` is annotated
`ios(15.0)` and the 10.0.1 cache has exported it since - and `carried` is `introduced <= deployment`, so
a row that claims later than the export costs the port the band. `introduced` is therefore the release
that first exports the symbol.

| name | first exported | the object | header's annotation |
| --- | --- | --- | --- |
| `AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVCoordinatedPlaybackSuspensionReasonStallRecovery` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVCoordinatedPlaybackSuspensionReasonUserActionRequired` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVMetadataCommonIdentifierAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataCommonKeyAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataISOUserDataKeyAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataIdentifierISOUserDataAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataIdentifierQuickTimeMetadataAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataIdentifierQuickTimeMetadataAutoLivePhoto` | 12.0 | `MetadataKeyspaces12.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedCatBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedDogBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedHumanBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedSalientObject` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataIsMontage` | 10.0.1 | `MetadataKeyspaces10.m` | 15.0 |
| `AVMetadataIdentifierQuickTimeMetadataLivePhotoVitalityScore` | 12.0 | `MetadataKeyspaces12.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataLivePhotoVitalityScoringVersion` | 12.0 | `MetadataKeyspaces12.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataLocationHorizontalAccuracyInMeters` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataIdentifierQuickTimeMetadataSpatialOverCaptureQualityScore` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeMetadataSpatialOverCaptureQualityScoringVersion` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataIdentifierQuickTimeUserDataAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataObjectTypeCatBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataObjectTypeCodabarCode` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeDogBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataObjectTypeGS1DataBarCode` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeGS1DataBarExpandedCode` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeGS1DataBarLimitedCode` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeHumanBody` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataObjectTypeMicroPDF417Code` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeMicroQRCode` | 16.0 | `MetadataKeyspaces154.m` | 15.4 |
| `AVMetadataObjectTypeSalientObject` | 16.0 | `MetadataKeyspaces13.m` | 13.0 |
| `AVMetadataQuickTimeMetadataKeyAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVMetadataQuickTimeMetadataKeyIsMontage` | 10.0.1 | `MetadataKeyspaces10.m` | 15.0 |
| `AVMetadataQuickTimeUserDataKeyAccessibilityDescription` | 16.0 | `MetadataKeyspaces14.m` | 14.0 |
| `AVPlaybackCoordinatorOtherParticipantsDidChangeNotification` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerRateDidChangeNotification` | 12.0 | `CoordinatedPlaybackReasons12.m` | 15.0 |
| `AVPlayerRateDidChangeOriginatingParticipantKey` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerRateDidChangeReasonAppBackgrounded` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerRateDidChangeReasonAudioSessionInterrupted` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerRateDidChangeReasonKey` | 12.0 | `CoordinatedPlaybackReasons12.m` | 15.0 |
| `AVPlayerRateDidChangeReasonSetRateCalled` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerRateDidChangeReasonSetRateFailed` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerWaitingDuringInterstitialEventReason` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |
| `AVPlayerWaitingForCoordinatedPlaybackReason` | 16.0 | `CoordinatedPlaybackReasons15.m` | 15.0 |

## Reuse, and what was searched for first

The tree already carried `AVPlaybackCoordinatorOtherParticipantsDidChangeNotification`'s neighbours
from other families and the `AVAssetDownloadedAssetEvictionPriority*` pattern in
`AVFoundationConstants110.m`, which is the same shape of file. The only AVFoundation coordinated
playback work in the tree before this was `AVAudioSession+CategoryModeOptions.m` and
`AVCaptureSession+ApplicationAudioSession7.m`, which cover the audio-session reasons these suspension
reasons name; nothing here duplicates them, and the relationship is recorded in
[AVFoundationOwed.md](AVFoundationOwed.md), which also carries the rows of this family that are still
owed - the classes `AVPlaybackCoordinator`, `AVDelegatingPlaybackCoordinator` and their command
objects, which are objects with behaviour and not names, and so need an oracle of their own.
