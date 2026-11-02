#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_BaseLayerBitRateFraction) = CFSTR("BaseLayerBitRateFraction");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_BaseLayerFrameRateFraction) = CFSTR("BaseLayerFrameRateFraction");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_ConstantBitRate) = CFSTR("ConstantBitRate");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_EnableLTR) = CFSTR("EnableLTR");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_EstimatedAverageBytesPerFrame) = CFSTR("kVTProCodecPropertyKey_AverageBytesPerFrame");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HDRMetadataInsertionMode) = CFSTR("HDRMetadataInsertionMode");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_HorizontalFieldOfView) = CFSTR("HorizontalFieldOfView");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MaxAllowedFrameQP) = CFSTR("MaxAllowedFrameQP");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MinAllowedFrameQP) = CFSTR("MinAllowedFrameQP");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_OutputBitDepth) = CFSTR("OutputBitDepth");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_PreserveAlphaChannel) = CFSTR("kVTCodecPropertyKey_PreserveAlphaChannel");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_PreserveDynamicHDRMetadata) = CFSTR("PreserveDynamicHDRMetadata");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_ReferenceBufferCount) = CFSTR("ReferenceBufferCount");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_SupportsBaseFrameQP) = CFSTR("SupportsBaseFrameQP");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_PropagatePerFrameHDRDisplayMetadata) = CFSTR("PropagatePerFrameHDRDisplayMetadata");
const CFStringRef BACKPORT_IMPL(kVTEncodeFrameOptionKey_AcknowledgedLTRTokens) = CFSTR("AcknowledgedLTRTokens");
const CFStringRef BACKPORT_IMPL(kVTEncodeFrameOptionKey_BaseFrameQP) = CFSTR("BaseFrameQP");
const CFStringRef BACKPORT_IMPL(kVTEncodeFrameOptionKey_ForceLTRRefresh) = CFSTR("ForceLTRRefresh");
const CFStringRef BACKPORT_IMPL(kVTHDRMetadataInsertionMode_Auto) = CFSTR("HDRMetadataInsertionMode_Auto");
const CFStringRef BACKPORT_IMPL(kVTHDRMetadataInsertionMode_None) = CFSTR("HDRMetadataInsertionMode_None");
const CFStringRef BACKPORT_IMPL(kVTPixelRotationPropertyKey_FlipHorizontalOrientation) = CFSTR("FlipHorizontalOrientation");
const CFStringRef BACKPORT_IMPL(kVTPixelRotationPropertyKey_FlipVerticalOrientation) = CFSTR("FlipVerticalOrientation");
const CFStringRef BACKPORT_IMPL(kVTPixelRotationPropertyKey_Rotation) = CFSTR("Rotation");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_ConstrainedBaseline_AutoLevel) = CFSTR("H264_ConstrainedBaseline_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_H264_ConstrainedHigh_AutoLevel) = CFSTR("H264_ConstrainedHigh_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_HEVC_Main42210_AutoLevel) = CFSTR("HEVC_Main42210_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTRotation_0) = CFSTR("Rotation0");
const CFStringRef BACKPORT_IMPL(kVTRotation_180) = CFSTR("Rotation180");
const CFStringRef BACKPORT_IMPL(kVTRotation_CCW90) = CFSTR("RotationCCW90");
const CFStringRef BACKPORT_IMPL(kVTRotation_CW90) = CFSTR("RotationCW90");
const CFStringRef BACKPORT_IMPL(kVTSampleAttachmentKey_RequireLTRAcknowledgementToken) = CFSTR("RequireLTRAcknowledgementToken");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderListOption_IncludeStandardDefinitionDVEncoders) = CFSTR("IncludeStandardDefinitionDVEncoders");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_SupportsFrameReordering) = CFSTR("SupportsFrameReordering");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderSpecification_EnableLowLatencyRateControl) = CFSTR("EnableLowLatencyRateControl");
