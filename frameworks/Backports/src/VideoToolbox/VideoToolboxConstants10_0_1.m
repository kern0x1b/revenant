#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTPixelTransferPropertyKey_DestinationColorPrimaries) = CFSTR("DestinationColorPrimaries");
const CFStringRef BACKPORT_IMPL(kVTPixelTransferPropertyKey_DestinationICCProfile) = CFSTR("DestinationICCProfile");
const CFStringRef BACKPORT_IMPL(kVTPixelTransferPropertyKey_DestinationTransferFunction) = CFSTR("DestinationTransferFunction");
