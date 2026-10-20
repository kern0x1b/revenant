# The sample-buffer keys of iOS 7 to 16 on a release that has none of them

iOS 6 exports 37 `CMSampleBuffer` functions and none of these keys. Every one of the 25 below is a
`CFStringRef` the application passes to `CMBlockBufferSetAttachments` or reads back, so the port has to
carry a real string, not a placeholder: an attachment written under the wrong key is an attachment the
reader never finds.

Each value was read out of the host's own CoreMedia (`xcrun clang` against
`/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`, macOS 27.0) by asking the constant for its
`CFStringGetCString` bytes, one at a time, and comparing what came back with what the file carries. None
of them is invented and none is a guess at Apple's naming.

| constant | release | value |
| --- | --- | --- |
| `kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo` | 7.0 | `DroppedFrameReasonInfo` |
| `kCMSampleBufferDroppedFrameReasonInfo_CameraModeSwitch` | 7.0 | `CameraModeSwitch` |
| `kCMSampleBufferAttachmentKey_ForceKeyFrame` | 8.0 | `ForceKeyFrame` |
| `kCMSampleBufferNotificationParameter_OSStatus` | 8.0 | `OSStatus` |
| `kCMSampleBufferNotification_DataFailed` | 8.0 | `CMSampleBufferDataFailed` |
| `kCMSampleBufferAttachmentKey_StillImageLensStabilizationInfo` | 9.0 | `StillImageLensStabilizationInfo` |
| `kCMSampleBufferLensStabilizationInfo_Active` | 9.0 | `Active` |
| `kCMSampleBufferLensStabilizationInfo_Off` | 9.0 | `Off` |
| `kCMSampleBufferLensStabilizationInfo_OutOfRange` | 9.0 | `OutOfRange` |
| `kCMSampleBufferLensStabilizationInfo_Unavailable` | 9.0 | `Unavailable` |
| `kCMHEVCTemporalLevelInfoKey_ProfileSpace` | 11.0 | `ProfileSpace` |
| `kCMHEVCTemporalLevelInfoKey_ProfileIndex` | 11.0 | `ProfileIndex` |
| `kCMHEVCTemporalLevelInfoKey_ProfileCompatibilityFlags` | 11.0 | `ProfileCompatibilityFlags` |
| `kCMHEVCTemporalLevelInfoKey_TierFlag` | 11.0 | `TierFlag` |
| `kCMHEVCTemporalLevelInfoKey_LevelIndex` | 11.0 | `LevelIndex` |
| `kCMHEVCTemporalLevelInfoKey_ConstraintIndicatorFlags` | 11.0 | `ConstraintIndicatorFlags` |
| `kCMHEVCTemporalLevelInfoKey_TemporalLevel` | 11.0 | `TemporalLevel` |
| `kCMSampleAttachmentKey_HEVCTemporalLevelInfo` | 11.0 | `HEVCTemporalLevelInfo` |
| `kCMSampleAttachmentKey_HEVCTemporalSubLayerAccess` | 11.0 | `HEVCTemporalSubLayerAccess` |
| `kCMSampleAttachmentKey_HEVCStepwiseTemporalSubLayerAccess` | 11.0 | `HEVCStepwiseTemporalSubLayerAccess` |
| `kCMSampleAttachmentKey_HEVCSyncSampleNALUnitType` | 11.0 | `HEVCSyncSampleNALUnitType` |
| `kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix` | 11.0 | `CameraIntrinsicMatrix` |
| `kCMSampleAttachmentKey_AudioIndependentSampleDecoderRefreshCount` | 13.0 | `AudioIndependentSampleDecoderRefreshCount` |
| `kCMSampleAttachmentKey_CryptorSubsampleAuxiliaryData` | 15.0 | `CryptorSubsampleAuxiliaryData` |
| `kCMSampleAttachmentKey_HDR10PlusPerFrameData` | 16.0 | `HDR10PlusPerFrameData` |

One object per release, so the band machinery can drop each from the bands that already have it:
`CMSampleBuffer7.m` and `CMSampleBuffer8.m` carry the 7.0 and 8.0 pairs, `CMSampleBuffer9.m` the 9.0
five, `CMSampleBuffer11.m` the 11.0 twelve, `CMSampleBuffer13.m`, `CMSampleBuffer15.m` and
`CMSampleBuffer16.m` one each.
