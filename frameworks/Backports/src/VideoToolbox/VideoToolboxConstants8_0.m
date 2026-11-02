#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

const CFStringRef BACKPORT_IMPL(kVTDecompressionPropertyKey_RealTime) = CFSTR("RealTime");
const CFStringRef BACKPORT_IMPL(kVTPixelTransferPropertyKey_DestinationYCbCrMatrix) = CFSTR("DestinationYCbCrMatrix");
