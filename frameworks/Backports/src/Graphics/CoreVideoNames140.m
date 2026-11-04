#include "../revenant_impl.h"
#import <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_BlackLevel) = CFSTR("ProResRAW_BlackLevel");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_ColorMatrix) = CFSTR("ProResRAW_ColorMatrix");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_GainFactor) = CFSTR("ProResRAW_GainFactor");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_RecommendedCrop) = CFSTR("ProResRAW_RecommendedCrop");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_SenselSitingOffsets) = CFSTR("ProResRAW_SenselSitingOffsets");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_WhiteBalanceBlueFactor) = CFSTR("ProResRAW_WhiteBalanceBlueFactor");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_WhiteBalanceCCT) = CFSTR("ProResRAW_WhiteBalanceCCT");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_WhiteBalanceRedFactor) = CFSTR("ProResRAW_WhiteBalanceRedFactor");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferProResRAWKey_WhiteLevel) = CFSTR("ProResRAW_WhiteLevel");
const CFStringRef BACKPORT_IMPL(kCVPixelBufferVersatileBayerKey_BayerPattern) = CFSTR("ProResRAW_BayerPattern");
