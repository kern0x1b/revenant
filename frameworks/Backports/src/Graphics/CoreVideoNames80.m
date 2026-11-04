#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCVImageBufferAlphaChannelIsOpaque) = CFSTR("AlphaChannelIsOpaque");
const CFStringRef BACKPORT_IMPL(kCVMetalTextureCacheMaximumTextureAgeKey) = CFSTR("MaximumMetalTextureAge");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferMetalCompatibilityKey) = CFSTR("MetalCompatibility");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatContainsRGB) = CFSTR("ContainsRGB");
const CFStringRef BACKPORT_IMPL(kCVPixelFormatContainsYCbCr) = CFSTR("ContainsYCbCr");
