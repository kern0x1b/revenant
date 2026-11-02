#include "../revenant_impl.h"
#import <CoreImage/CoreImage.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

NSString *const BACKPORT_IMPL(kCIImageApplyOrientationProperty) = @"kCIImageApplyOrientationProperty";
NSString *const BACKPORT_IMPL(kCIImageAuxiliaryDepth) = @"kCIImageAuxiliaryDepth";
NSString *const BACKPORT_IMPL(kCIImageAuxiliaryDisparity) = @"kCIImageAuxiliaryDisparity";
NSString *const BACKPORT_IMPL(kCIImageRepresentationAVDepthData) = @"kCIImageRepresentationAVDepthData";
NSString *const BACKPORT_IMPL(kCIImageRepresentationDepthImage) = @"kCIImageRepresentationDepthImage";
NSString *const BACKPORT_IMPL(kCIImageRepresentationDisparityImage) = @"kCIImageRepresentationDisparityImage";
NSString *const BACKPORT_IMPL(kCIInputDepthImageKey) = @"inputDepthImage";
NSString *const BACKPORT_IMPL(kCIInputDisparityImageKey) = @"inputDisparityImage";
NSString *const kCIInputMoireAmountKey = @"inputMoireAmount";
