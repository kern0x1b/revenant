#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 16.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. The fifteen the held iOS 13.4 image exports first are in
// VideoToolboxConstants13_4.m. An object carries the API of one release.

const CFStringRef kVTCompressionPropertyKey_BaseLayerBitRateFraction = CFSTR("BaseLayerBitRateFraction");
const CFStringRef kVTCompressionPropertyKey_BaseLayerFrameRateFraction = CFSTR("BaseLayerFrameRateFraction");
const CFStringRef kVTCompressionPropertyKey_ConstantBitRate = CFSTR("ConstantBitRate");
const CFStringRef kVTCompressionPropertyKey_EnableLTR = CFSTR("EnableLTR");
const CFStringRef kVTCompressionPropertyKey_EstimatedAverageBytesPerFrame = CFSTR("kVTProCodecPropertyKey_AverageBytesPerFrame");
const CFStringRef kVTCompressionPropertyKey_HDRMetadataInsertionMode = CFSTR("HDRMetadataInsertionMode");
const CFStringRef kVTCompressionPropertyKey_HorizontalFieldOfView = CFSTR("HorizontalFieldOfView");
const CFStringRef kVTCompressionPropertyKey_MaxAllowedFrameQP = CFSTR("MaxAllowedFrameQP");
const CFStringRef kVTCompressionPropertyKey_MinAllowedFrameQP = CFSTR("MinAllowedFrameQP");
const CFStringRef kVTCompressionPropertyKey_OutputBitDepth = CFSTR("OutputBitDepth");
const CFStringRef kVTCompressionPropertyKey_PreserveAlphaChannel = CFSTR("kVTCodecPropertyKey_PreserveAlphaChannel");
const CFStringRef kVTCompressionPropertyKey_PreserveDynamicHDRMetadata = CFSTR("PreserveDynamicHDRMetadata");
const CFStringRef kVTCompressionPropertyKey_ReferenceBufferCount = CFSTR("ReferenceBufferCount");
const CFStringRef kVTCompressionPropertyKey_SupportsBaseFrameQP = CFSTR("SupportsBaseFrameQP");
const CFStringRef kVTDecompressionPropertyKey_PropagatePerFrameHDRDisplayMetadata = CFSTR("PropagatePerFrameHDRDisplayMetadata");
const CFStringRef kVTEncodeFrameOptionKey_AcknowledgedLTRTokens = CFSTR("AcknowledgedLTRTokens");
const CFStringRef kVTEncodeFrameOptionKey_BaseFrameQP = CFSTR("BaseFrameQP");
const CFStringRef kVTEncodeFrameOptionKey_ForceLTRRefresh = CFSTR("ForceLTRRefresh");
const CFStringRef kVTHDRMetadataInsertionMode_Auto = CFSTR("HDRMetadataInsertionMode_Auto");
const CFStringRef kVTHDRMetadataInsertionMode_None = CFSTR("HDRMetadataInsertionMode_None");
const CFStringRef kVTPixelRotationPropertyKey_FlipHorizontalOrientation = CFSTR("FlipHorizontalOrientation");
const CFStringRef kVTPixelRotationPropertyKey_FlipVerticalOrientation = CFSTR("FlipVerticalOrientation");
const CFStringRef kVTPixelRotationPropertyKey_Rotation = CFSTR("Rotation");
const CFStringRef kVTProfileLevel_H264_ConstrainedBaseline_AutoLevel = CFSTR("H264_ConstrainedBaseline_AutoLevel");
const CFStringRef kVTProfileLevel_H264_ConstrainedHigh_AutoLevel = CFSTR("H264_ConstrainedHigh_AutoLevel");
const CFStringRef kVTProfileLevel_HEVC_Main42210_AutoLevel = CFSTR("HEVC_Main42210_AutoLevel");
const CFStringRef kVTRotation_0 = CFSTR("Rotation0");
const CFStringRef kVTRotation_180 = CFSTR("Rotation180");
const CFStringRef kVTRotation_CCW90 = CFSTR("RotationCCW90");
const CFStringRef kVTRotation_CW90 = CFSTR("RotationCW90");
const CFStringRef kVTSampleAttachmentKey_RequireLTRAcknowledgementToken = CFSTR("RequireLTRAcknowledgementToken");
const CFStringRef kVTVideoEncoderListOption_IncludeStandardDefinitionDVEncoders = CFSTR("IncludeStandardDefinitionDVEncoders");
const CFStringRef kVTVideoEncoderList_SupportsFrameReordering = CFSTR("SupportsFrameReordering");
const CFStringRef kVTVideoEncoderSpecification_EnableLowLatencyRateControl = CFSTR("EnableLowLatencyRateControl");
