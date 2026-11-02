#include "../revenant_impl.h"
#import <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>

const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionExtension_ProjectionKind) = CFSTR("ProjectionKind");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionExtension_ViewPackingKind) = CFSTR("ViewPackingKind");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionProjectionKind_Equirectangular) = CFSTR("Equirectangular");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionProjectionKind_HalfEquirectangular) = CFSTR("HalfEquirectangular");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionProjectionKind_Rectilinear) = CFSTR("Rectilinear");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionViewPackingKind_OverUnder) = CFSTR("OverUnder");
const CFStringRef BACKPORT_IMPL(kCMFormatDescriptionViewPackingKind_SideBySide) = CFSTR("SideBySide");
