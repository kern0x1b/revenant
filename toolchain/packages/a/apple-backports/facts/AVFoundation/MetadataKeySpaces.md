# The metadata key-space names

Thirty constants, in the four key spaces Apple's own tables name: the QuickTime metadata key space
(`mdta/`), the ISO user data space (`uiso/`), the QuickTime user data space (`udta/`), the common
space (`common/`), and the object types a machine-readable code names. `packages/a/apple-backports/AVFoundation/`
carries them in three files, one per release they arrived in.

## How the values were read

Not out of a header. Each name was resolved as an exported symbol in the **host's own AVFoundation**
with `dlsym(RTLD_DEFAULT, name)` and the `NSString *const` it points at printed, twice: once as text
and once as bytes, so that a value with a non-ASCII byte could not be mistaken for a rendering
accident. All 28 answered; none was absent from the host.

Then the same table was read out of two builds and the two were diffed, which is what
`tests/backports/host/avf-metadata/run.sh` does: once linked against Apple's framework alone, and
once with the port's three files in the same binary, every name renamed to `charon_host_<name>` so
the port's definition and Apple's sit side by side. The port's table is byte-identical to the host's.

Two things that measurement settled, and which a header reading would have got wrong:

- **`AVMetadataIdentifierQuickTimeUserDataAccessibilityDescription` is the eleven ASCII characters
  `udta/%A9ade`.** The `%A9` is literal text - a percent, a capital A, a nine - not a copyright sign
  and not the byte 0xA9. The byte dump reads `75 64 74 61 2f 25 41 39 61 64 65`, all of them below
  0x80.
- **`AVMetadataObjectTypeCodabarCode` is `Codabar`**, a capital C, while the five GS1 and ISO types
  beside it are lower-case dotted names. The mutant in the differential is exactly that one letter,
  because a case difference in a UTI is the kind of thing no address comparison would see.

## The values

| constant | value the host answered | bytes |
| --- | --- | --- |
| `AVMetadataCommonIdentifierAccessibilityDescription` | "common/accessibilityDescription" | 31 |
| `AVMetadataCommonKeyAccessibilityDescription` | "accessibilityDescription" | 24 |
| `AVMetadataISOUserDataKeyAccessibilityDescription` | "ades" | 4 |
| `AVMetadataIdentifierISOUserDataAccessibilityDescription` | "uiso/ades" | 9 |
| `AVMetadataIdentifierQuickTimeMetadataAccessibilityDescription` | "mdta/com.apple.quicktime.accessibility.description" | 50 |
| `AVMetadataIdentifierQuickTimeMetadataAutoLivePhoto` | "mdta/com.apple.quicktime.live-photo.auto" | 40 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedCatBody` | "mdta/com.apple.quicktime.detected-cat-body" | 42 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedDogBody` | "mdta/com.apple.quicktime.detected-dog-body" | 42 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedHumanBody` | "mdta/com.apple.quicktime.detected-human-body" | 44 |
| `AVMetadataIdentifierQuickTimeMetadataDetectedSalientObject` | "mdta/com.apple.quicktime.detected-salient-object" | 48 |
| `AVMetadataIdentifierQuickTimeMetadataLivePhotoVitalityScore` | "mdta/com.apple.quicktime.live-photo.vitality-score" | 50 |
| `AVMetadataIdentifierQuickTimeMetadataLivePhotoVitalityScoringVersion` | "mdta/com.apple.quicktime.live-photo.vitality-scoring-version" | 60 |
| `AVMetadataIdentifierQuickTimeMetadataLocationHorizontalAccuracyInMeters` | "mdta/com.apple.quicktime.location.accuracy.horizontal" | 53 |
| `AVMetadataIdentifierQuickTimeMetadataSpatialOverCaptureQualityScore` | "mdta/com.apple.quicktime.spatial-overcapture.quality-score" | 58 |
| `AVMetadataIdentifierQuickTimeMetadataSpatialOverCaptureQualityScoringVersion` | "mdta/com.apple.quicktime.spatial-overcapture.quality-scoring-version" | 68 |
| `AVMetadataIdentifierQuickTimeUserDataAccessibilityDescription` | "udta/%A9ade" | 11 |
| `AVMetadataObjectTypeCatBody` | "catBody" | 7 |
| `AVMetadataObjectTypeCodabarCode` | "Codabar" | 7 |
| `AVMetadataObjectTypeDogBody` | "dogBody" | 7 |
| `AVMetadataObjectTypeGS1DataBarCode` | "org.gs1.GS1DataBar" | 18 |
| `AVMetadataObjectTypeGS1DataBarExpandedCode` | "org.gs1.GS1DataBarExpanded" | 26 |
| `AVMetadataObjectTypeGS1DataBarLimitedCode` | "org.gs1.GS1DataBarLimited" | 25 |
| `AVMetadataObjectTypeHumanBody` | "humanBody" | 9 |
| `AVMetadataObjectTypeMicroPDF417Code` | "org.iso.MicroPDF417" | 19 |
| `AVMetadataObjectTypeMicroQRCode` | "org.iso.MicroQR" | 15 |
| `AVMetadataObjectTypeSalientObject` | "salientObject" | 13 |
| `AVMetadataQuickTimeMetadataKeyAccessibilityDescription` | "com.apple.quicktime.accessibility.description" | 45 |
| `AVMetadataQuickTimeUserDataKeyAccessibilityDescription` | "@ade" | 4 |

## What is not here

The metadata *objects* - `AVMetadataItemFilter`, `AVMetadataGroup`, `AVDateRangeMetadataGroup`,
`AVMutableDateRangeMetadataGroup`, `AVMetadataItemValueRequest` and the five body-object classes -
are owed and are written down in [AVFoundationOwed.md](AVFoundationOwed.md) with the measurement that
says why this file does not carry them. Two of the reasons are worth repeating here because they
decided the shape of this slice:

- **The host will not build one.** `+[AVMetadataItem metadataItemWithIdentifier:value:extraAttributes:]`
  does not exist on the host build, `-[AVMetadataGroup initWithItems:]` does not, and
  `-[AVMetadataItemFilter initWithIdentifiers:]` does not. A differential needs both sides to answer
  the same question from the same input, and there is no public way to hand Apple's classes an input,
  so there is nothing to compare. The current spelling of that filter's member is `allowList`, and
  the 7.0-era `identifiers` is not in the host build at all.
- **The body-object classes carry state a detection produces.** Measured on the host:
  `AVMetadataBodyObject` has 5 own methods and an instance size of 24, `AVMetadataHumanBodyObject`
  has 8 and an instance size of 40, and the three others have 6 or 7. An empty class of that name
  would resolve every `isKindOfClass:` and answer nothing, which is the silent shape this registry
  calls out by name; those rows want `inert` with the effect written down, or a real body-object
  behind a capture pipeline this port does not have.


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

`AVMetadataItem+Identifiers8.m` already carries the 8.0 identifiers and the three properties, and its
facts file `AVMetadataItemIdentifiers.md` records the key-space arithmetic they do. Nothing here
duplicates it: the 8.0 names are not in this slice and the 13.0+ names do not collide with them. The
existing constant files (`AVFoundationConstants90.m` … `AVFoundationConstants120.m`) are the pattern
followed for the shape of a constants file, and the missing names there are why these rows were
`absent` rather than written down earlier.
