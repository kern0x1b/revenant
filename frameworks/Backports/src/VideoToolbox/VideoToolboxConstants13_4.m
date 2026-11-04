#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTAlphaChannelMode_PremultipliedAlpha) = CFSTR("PremultipliedAlpha");
const CFStringRef BACKPORT_IMPL(kVTAlphaChannelMode_StraightAlpha) = CFSTR("StraightAlpha");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_AlphaChannelMode) = CFSTR("AlphaChannelMode");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality) = CFSTR("PrioritizeEncodingSpeedOverQuality");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_TargetQualityForAlpha) = CFSTR("TargetQualityForAlpha");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_UsingGPURegistryID) = CFSTR("UsingMetalRegistryID");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_UsingGPURegistryID) = CFSTR("UsingMetalRegistryID");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_HEVC_Monochrome10_AutoLevel) = CFSTR("HEVC_Monochrome10_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_GPURegistryID) = CFSTR("GPURegistryID");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_InstanceLimit) = CFSTR("InstanceLimit");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_PerformanceRating) = CFSTR("PerformanceRating");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_QualityRating) = CFSTR("QualityRating");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderList_SupportedSelectionProperties) = CFSTR("SupportedSelectionProperties");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderSpecification_PreferredEncoderGPURegistryID) = CFSTR("PreferredEncoderGPURegistryID");
const CFStringRef BACKPORT_IMPL(kVTVideoEncoderSpecification_RequiredEncoderGPURegistryID) = CFSTR("RequiredEncoderGPURegistryID");
