#import <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>

const CFStringRef kCMFormatDescriptionExtension_ProjectionKind = CFSTR("ProjectionKind");
const CFStringRef kCMFormatDescriptionExtension_ViewPackingKind = CFSTR("ViewPackingKind");
const CFStringRef kCMFormatDescriptionProjectionKind_Equirectangular = CFSTR("Equirectangular");
const CFStringRef kCMFormatDescriptionProjectionKind_HalfEquirectangular = CFSTR("HalfEquirectangular");
const CFStringRef kCMFormatDescriptionProjectionKind_Rectilinear = CFSTR("Rectilinear");
const CFStringRef kCMFormatDescriptionViewPackingKind_OverUnder = CFSTR("OverUnder");
const CFStringRef kCMFormatDescriptionViewPackingKind_SideBySide = CFSTR("SideBySide");
