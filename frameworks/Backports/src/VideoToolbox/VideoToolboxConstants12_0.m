#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_AllowOpenGOP) = CFSTR("AllowOpenGOP");
const CFStringRef BACKPORT_IMPL(kVTCompressionPropertyKey_MaximizePowerEfficiency) = CFSTR("MaximizePowerEfficiency");
const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_MaximizePowerEfficiency) = CFSTR("MaximizePowerEfficiency");
const CFStringRef BACKPORT_IMPL(kVTVideoDecoderSpecification_PreferredDecoderGPURegistryID) = CFSTR("PreferredDecoderGPURegistryID");
const CFStringRef BACKPORT_IMPL(kVTVideoDecoderSpecification_RequiredDecoderGPURegistryID) = CFSTR("RequiredDecoderGPURegistryID");
