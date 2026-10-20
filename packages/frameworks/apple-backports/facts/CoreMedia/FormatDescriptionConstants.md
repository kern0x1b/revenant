# The format-description keys of iOS 8 to 26 on a release that has none of them

75 `CFStringRef` constants, from the eight releases that added them to `CMFormatDescription.h`. Each
value was read out of the host's own CoreMedia - `xcrun clang` against
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`, macOS 27.0 - by asking the constant for its
`CFStringGetCString` bytes, one at a time, and none of them is inferred from the constant's own name.
That matters here more than usual: 48 of the 75 are **not** their name's last component.
`kCMFormatDescriptionChromaLocation_DV420` is `DV 4:2:0`, `kCMFormatDescriptionLogTransferFunction_AppleLog`
is `com.apple.rec2020.apple-log`, and ten of the `kCMFormatDescriptionExtension_*` keys are CoreVideo's
own under another name (`CVCleanAperture`, `CVFieldCount`, `CVImageBufferColorPrimaries`, ...). A value
guessed from the name would have been wrong 48 times.

## 37 of the 113 rows the corpus lists for this header are not rows at all

The corpus names 113 missing constants for `CMFormatDescription.h`. **37 of them are `#define`s in the
26.2 header of another name, and every one of those names iOS 6.0 already exports.** The header declares
both an `extern` and a `#define` for the same identifier, and the `#define` wins:

```c
extern const CFStringRef kCMFormatDescriptionChromaLocation_Bottom;        // 26.2 header, line 816
#define kCMFormatDescriptionChromaLocation_Bottom kCVImageBufferChromaLocation_Bottom   // line 825
```

So an application that writes `kCMFormatDescriptionChromaLocation_Bottom` is compiled into a reference
to `kCVImageBufferChromaLocation_Bottom`, which iOS 6.0 exports (`coordination/corpus/caches/6.0.tsv`).
Nothing is needed from the port, and defining the name here would be defining a symbol no application
references. The family is therefore **75 constants**, and
`.agent-work/plan-and-analysis/coremedia-avf/missing-by-header.py` now resolves `#define` aliases and
reads enum cases out of the header, so the inventory is 75 rather than 113.

The 76th row of the corrected list, `kCMMuxedStreamType_EmbeddedDeviceScreenRecording`, is a case of an
enumeration in the header (`= 'isr '`), so the compiler writes it into the application and it needs
nothing here either.

## One constant the host harness cannot rename

`kCMFormatDescriptionTransferFunction_SMPTE_ST_428_1` is declared in **both** SDKs on this machine with
no semicolon after the name:

```
CM_EXPORT const CFStringRef kCMFormatDescriptionTransferFunction_SMPTE_ST_428_1   // same as kCVImageBufferTransferFunction_SMPTE_ST_428_1
                        API_AVAILABLE(macos(10.12), ios(10.0), tvos(10.0), watchos(6.0), visionos(1.0));
```

so `-D` renaming that identifier cannot compile against either SDK, and
`tests/backports/host/coremedia7` holds the other **74** to the host's own bytes. This one's value was
read out of the host the same way as the rest and is in the table; it is simply not re-checked by the
harness. The port's own build is unaffected: every one of these objects compiles clean against the
iOS 16.4 SDK for `armv7-apple-ios6.0`, which is what the gate does. The set is the constant carriers in
the table below plus the two objects in this family that carry no constant - `CMFormatDescription11.m`,
the HEVC parameter-set reader, and `CMFormatDescription260.m`, whose keys the 26.0 SDK declares - and
`tools/release-split.lua` over the gate's objects is what checks the one-object-per-release rule, so a
new file cannot leave this sentence out of date.

## The values

| constant | value |
| --- | --- |
| `kCMFormatDescriptionAlphaChannelMode_PremultipliedAlpha` | `PremultipliedAlpha` |
| `kCMFormatDescriptionAlphaChannelMode_StraightAlpha` | `StraightAlpha` |
| `kCMFormatDescriptionCameraCalibrationExtrinsicOriginSource_StereoCameraSystemBaseline` | `StereoCameraSystemBaseline` |
| `kCMFormatDescriptionCameraCalibrationLensAlgorithmKind_ParametricLens` | `ParametricLens` |
| `kCMFormatDescriptionCameraCalibrationLensDomain_Color` | `Color` |
| `kCMFormatDescriptionCameraCalibrationLensRole_Left` | `Left` |
| `kCMFormatDescriptionCameraCalibrationLensRole_Mono` | `Mono` |
| `kCMFormatDescriptionCameraCalibrationLensRole_Right` | `Right` |
| `kCMFormatDescriptionCameraCalibration_ExtrinsicOrientationQuaternion` | `ExtrinsicOrientationQuaternion` |
| `kCMFormatDescriptionCameraCalibration_ExtrinsicOriginSource` | `ExtrinsicOriginSource` |
| `kCMFormatDescriptionCameraCalibration_IntrinsicMatrix` | `IntrinsicMatrix` |
| `kCMFormatDescriptionCameraCalibration_IntrinsicMatrixProjectionOffset` | `IntrinsicMatrixProjectionOffset` |
| `kCMFormatDescriptionCameraCalibration_IntrinsicMatrixReferenceDimensions` | `IntrinsicMatrixReferenceDimensions` |
| `kCMFormatDescriptionCameraCalibration_LensAlgorithmKind` | `LensAlgorithmKind` |
| `kCMFormatDescriptionCameraCalibration_LensDistortions` | `LensDistortions` |
| `kCMFormatDescriptionCameraCalibration_LensDomain` | `LensDomain` |
| `kCMFormatDescriptionCameraCalibration_LensFrameAdjustmentsPolynomialX` | `LensFrameAdjustmentsPolynomialX` |
| `kCMFormatDescriptionCameraCalibration_LensFrameAdjustmentsPolynomialY` | `LensFrameAdjustmentsPolynomialY` |
| `kCMFormatDescriptionCameraCalibration_LensIdentifier` | `LensIdentifier` |
| `kCMFormatDescriptionCameraCalibration_LensRole` | `LensRole` |
| `kCMFormatDescriptionCameraCalibration_RadialAngleLimit` | `RadialAngleLimit` |
| `kCMFormatDescriptionColorPrimaries_DCI_P3` | `DCI_P3` |
| `kCMFormatDescriptionColorPrimaries_ITU_R_2020` | `ITU_R_2020` |
| `kCMFormatDescriptionColorPrimaries_P3_D65` | `P3_D65` |
| `kCMFormatDescriptionExtension_AlphaChannelMode` | `AlphaChannelMode` |
| `kCMFormatDescriptionExtension_AlternativeTransferCharacteristics` | `AlternativeTransferCharacteristics` |
| `kCMFormatDescriptionExtension_AmbientViewingEnvironment` | `AmbientViewingEnvironment` |
| `kCMFormatDescriptionExtension_AuxiliaryTypeInfo` | `AuxiliaryTypeInfo` |
| `kCMFormatDescriptionExtension_BitsPerComponent` | `BitsPerComponent` |
| `kCMFormatDescriptionExtension_CameraCalibrationDataLensCollection` | `CameraCalibrationDataLensCollection` |
| `kCMFormatDescriptionExtension_ContainsAlphaChannel` | `ContainsAlphaChannel` |
| `kCMFormatDescriptionExtension_ContentColorVolume` | `ContentColorVolume` |
| `kCMFormatDescriptionExtension_ContentLightLevelInfo` | `ContentLightLevelInfo` |
| `kCMFormatDescriptionExtension_ConvertedFromExternalSphericalTags` | `ConvertedFromExternalSphericalTags` |
| `kCMFormatDescriptionExtension_HasAdditionalViews` | `HasAdditionalViews` |
| `kCMFormatDescriptionExtension_HasLeftStereoEyeView` | `HasLeftStereoEyeView` |
| `kCMFormatDescriptionExtension_HasRightStereoEyeView` | `HasRightStereoEyeView` |
| `kCMFormatDescriptionExtension_HeroEye` | `HeroEye` |
| `kCMFormatDescriptionExtension_HorizontalDisparityAdjustment` | `HorizontalDisparityAdjustment` |
| `kCMFormatDescriptionExtension_HorizontalFieldOfView` | `HorizontalFieldOfView` |
| `kCMFormatDescriptionExtension_LogTransferFunction` | `LogTransferFunction` |
| `kCMFormatDescriptionExtension_MasteringDisplayColorVolume` | `MasteringDisplayColorVolume` |
| `kCMFormatDescriptionExtension_ProjectionKind` | `ProjectionKind` |
| `kCMFormatDescriptionExtension_ProtectedContentOriginalFormat` | `CommonEncryptionOriginalFormat` |
| `kCMFormatDescriptionExtension_StereoCameraBaseline` | `StereoCameraBaseline` |
| `kCMFormatDescriptionExtension_ViewPackingKind` | `ViewPackingKind` |
| `kCMFormatDescriptionHeroEye_Left` | `Left` |
| `kCMFormatDescriptionHeroEye_Right` | `Right` |
| `kCMFormatDescriptionLogTransferFunction_AppleLog` | `com.apple.rec2020.apple-log` |
| `kCMFormatDescriptionProjectionKind_AppleImmersiveVideo` | `AppleImmersiveVideo` |
| `kCMFormatDescriptionProjectionKind_Equirectangular` | `Equirectangular` |
| `kCMFormatDescriptionProjectionKind_HalfEquirectangular` | `HalfEquirectangular` |
| `kCMFormatDescriptionProjectionKind_ParametricImmersive` | `ParametricImmersive` |
| `kCMFormatDescriptionProjectionKind_Rectilinear` | `Rectilinear` |
| `kCMFormatDescriptionTransferFunction_ITU_R_2020` | `ITU_R_2020` |
| `kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG` | `ITU_R_2100_HLG` |
| `kCMFormatDescriptionTransferFunction_Linear` | `Linear` |
| `kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ` | `SMPTE_ST_2084_PQ` |
| `kCMFormatDescriptionTransferFunction_SMPTE_ST_428_1` | `SMPTE_ST_428_1` |
| `kCMFormatDescriptionTransferFunction_sRGB` | `IEC_sRGB` |
| `kCMFormatDescriptionViewPackingKind_OverUnder` | `OverUnder` |
| `kCMFormatDescriptionViewPackingKind_SideBySide` | `SideBySide` |
| `kCMFormatDescriptionYCbCrMatrix_ITU_R_2020` | `ITU_R_2020` |
| `kCMMetadataFormatDescriptionKey_ConformingDataTypes` | `MetadataKeyConformingDataTypes` |
| `kCMMetadataFormatDescriptionKey_DataType` | `MetadataKeyDataType` |
| `kCMMetadataFormatDescriptionKey_DataTypeNamespace` | `MetadataKeyDataTypeNameSpace` |
| `kCMMetadataFormatDescriptionKey_LanguageTag` | `MetadataKeyLanguageTag` |
| `kCMMetadataFormatDescriptionKey_SetupData` | `MetadataKeySetupData` |
| `kCMMetadataFormatDescriptionKey_StructuralDependency` | `MetadataKeyStructuralDependency` |
| `kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType` | `MetadataDataType` |
| `kCMMetadataFormatDescriptionMetadataSpecificationKey_ExtendedLanguageTag` | `MetadataExtendedLanguageTag` |
| `kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier` | `MetadataIdentifier` |
| `kCMMetadataFormatDescriptionMetadataSpecificationKey_SetupData` | `MetadataKeySetupData` |
| `kCMMetadataFormatDescriptionMetadataSpecificationKey_StructuralDependency` | `StructuralDependency` |
| `kCMMetadataFormatDescription_StructuralDependencyKey_DependencyIsInvalidFlag` | `StructuralDependencyIsInvalidFlag` |

One object per release, so each band drops what it already has, and **the release is the one the armv7
cache ladder measures, not the one the SDK's availability gives** - where the two disagree the ladder
wins, because that is what the band machinery uses. Three names disagree:
`kCMFormatDescriptionExtension_AlternativeTransferCharacteristics` is `ios(12.0)` in the header and
first exported at 16.0, and `kCMMetadataFormatDescriptionKey_SetupData` and
`kCMMetadataFormatDescriptionMetadataSpecificationKey_SetupData` are `ios(9.0)` and first exported at
10.0.1. Each therefore has its own object, `CMFormatDescription160.m` and `CMFormatDescription1001.m`,
which is what `tools/release-split.lua` requires - "an object carries API that arrived in one release".
The registry's `introduced` keeps the SDK's number, as the registry convention says, and
`16.0` on the ladder is an upper bound: nothing is held between 12.0 and 16.0, so it means "after 12.0,
by 16.0" and never a measured 13.0-15.x.

`CMFormatDescription80.m` (7), `90.m` (8), `100.m` (1), `1001.m` (2), `110.m` (4), `120.m` (1),
`130.m` (6), `140.m` (1), `150.m` (3), `160.m` (1), `170.m` (9), `172.m` (2), `180.m` (7), `260.m` (23).

## Reuse

Searched: none of them, and the search is named so it can be repeated. The 2026-09-28 rule's upstream
table has no CoreMedia row; Apple's CoreMedia is not open-sourced, so there is no reference
implementation to take; WinObjC, Chameleon, OpenCombine and swift-corelibs-foundation do not carry
CMTag, CMTagCollection or CMTaggedBufferGroup. Every value in this family is the host's own bytes read
out of its CoreMedia, not anyone's implementation. FFmpeg's libavformat/libavcodec and GStreamer are
LGPL and were not read.
