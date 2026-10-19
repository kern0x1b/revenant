#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 11.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTCompressionPropertyKey_BaseLayerFrameRate = CFSTR("BaseLayerFrameRate");
const CFStringRef kVTCompressionPropertyKey_ContentLightLevelInfo = CFSTR("ContentLightLevelInfo");
const CFStringRef kVTCompressionPropertyKey_EncoderID = CFSTR("EncoderID");
const CFStringRef kVTCompressionPropertyKey_MasteringDisplayColorVolume = CFSTR("MasteringDisplayColorVolume");
const CFStringRef kVTDecompressionProperty_TemporalLevelLimit = CFSTR("TemporalLevelLimit");
const CFStringRef kVTProfileLevel_HEVC_Main10_AutoLevel = CFSTR("HEVC_Main10_AutoLevel");
const CFStringRef kVTProfileLevel_HEVC_Main_AutoLevel = CFSTR("HEVC_Main_AutoLevel");
const CFStringRef kVTProfileLevel_HEVC_Monochrome_AutoLevel = CFSTR("HEVC_Monochrome_AutoLevel");
