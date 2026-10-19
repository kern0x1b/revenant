#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

// The string constants VideoToolbox's first held export of which is iOS 10.0.1. Where the values
// come from, and why a value is not the constant's own name: the head of
// VideoToolboxConstants7_0.m. An object carries the API of one release.

const CFStringRef kVTPixelTransferPropertyKey_DestinationColorPrimaries = CFSTR("DestinationColorPrimaries");
const CFStringRef kVTPixelTransferPropertyKey_DestinationICCProfile = CFSTR("DestinationICCProfile");
const CFStringRef kVTPixelTransferPropertyKey_DestinationTransferFunction = CFSTR("DestinationTransferFunction");
