#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_BaseLayerFrameRate) = CFSTR("BaseLayerFrameRate");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_ContentLightLevelInfo) = CFSTR("ContentLightLevelInfo");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_EncoderID) = CFSTR("EncoderID");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MasteringDisplayColorVolume) = CFSTR("MasteringDisplayColorVolume");
const CFStringRef BACKPORT_IMPL(kVTDecompressionProperty_TemporalLevelLimit) = CFSTR("TemporalLevelLimit");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_HEVC_Main10_AutoLevel) = CFSTR("HEVC_Main10_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_HEVC_Main_AutoLevel) = CFSTR("HEVC_Main_AutoLevel");
const CFStringRef BACKPORT_IMPL(kVTProfileLevel_HEVC_Monochrome_AutoLevel) = CFSTR("HEVC_Monochrome_AutoLevel");
