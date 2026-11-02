#include "../revenant_impl.h"
#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

NSString *const BACKPORT_IMPL(kCIContextMemoryLimit) = @"kCIContextMemoryLimit";
NSString *const BACKPORT_IMPL(kCIImageContentHeadroom) = @"kCIImageContentHeadroom";
NSString *const BACKPORT_IMPL(kCIImageExpandToHDR) = @"kCIImageExpandToHDR";
NSString *const BACKPORT_IMPL(kCIImageRepresentationHDRGainMapAsRGB) = @"kCIImageRepresentationHDRGainMapAsRGB";
NSString *const BACKPORT_IMPL(kCIImageRepresentationHDRImage) = @"kCIImageRepresentationHDRImage";
