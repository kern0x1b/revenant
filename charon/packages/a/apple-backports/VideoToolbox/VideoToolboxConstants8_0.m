#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 8.0. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTDecompressionPropertyKey_RealTime = CFSTR("RealTime");
const CFStringRef kVTPixelTransferPropertyKey_DestinationYCbCrMatrix = CFSTR("DestinationYCbCrMatrix");
