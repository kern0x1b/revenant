#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef kVTCompressionPropertyKey_AllowOpenGOP = CFSTR("AllowOpenGOP");
const CFStringRef kVTCompressionPropertyKey_MaximizePowerEfficiency = CFSTR("MaximizePowerEfficiency");
const CFStringRef kVTDecompressionPropertyKey_MaximizePowerEfficiency = CFSTR("MaximizePowerEfficiency");
const CFStringRef kVTVideoDecoderSpecification_PreferredDecoderGPURegistryID = CFSTR("PreferredDecoderGPURegistryID");
const CFStringRef kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID = CFSTR("RequiredDecoderGPURegistryID");
