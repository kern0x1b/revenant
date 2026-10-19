#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 12.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTCompressionPropertyKey_AllowOpenGOP = CFSTR("AllowOpenGOP");
const CFStringRef kVTCompressionPropertyKey_MaximizePowerEfficiency = CFSTR("MaximizePowerEfficiency");
const CFStringRef kVTDecompressionPropertyKey_MaximizePowerEfficiency = CFSTR("MaximizePowerEfficiency");
const CFStringRef kVTVideoDecoderSpecification_PreferredDecoderGPURegistryID = CFSTR("PreferredDecoderGPURegistryID");
const CFStringRef kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID = CFSTR("RequiredDecoderGPURegistryID");
