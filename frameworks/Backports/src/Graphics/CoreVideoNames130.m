#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCVImageBufferAlphaChannelModeKey) = CFSTR("AlphaChannelMode");
const CFStringRef BACKPORT_IMPL(kCVImageBufferAlphaChannelMode_PremultipliedAlpha) = CFSTR("PremultipliedAlpha");
const CFStringRef BACKPORT_IMPL(kCVImageBufferAlphaChannelMode_StraightAlpha) = CFSTR("StraightAlpha");
const CFStringRef BACKPORT_IMPL(kCVMetalTextureStorageMode) = CFSTR("MetalTextureStorageMode");
