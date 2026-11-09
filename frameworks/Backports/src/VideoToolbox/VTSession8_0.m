#include "../revenant_impl.h"
#if defined(REVENANT_HOST_BUILD)
#define VTSessionSetProperty __revenant_fb_VTSessionSetProperty
#define VTSessionCopyProperty __revenant_fb_VTSessionCopyProperty
#endif

#import <CoreFoundation/CoreFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

#import "VTDecompressionSessionHEVC.h"
#import "VTSystem.h"

typedef OSStatus (*RevenantVTSetPropertyFunction)(VTSessionRef, CFStringRef, CFTypeRef);
typedef OSStatus (*RevenantVTCopyPropertyFunction)(VTSessionRef, CFStringRef, CFAllocatorRef, void *);

OSStatus BACKPORT_IMPL(VTSessionSetProperty)(VTSessionRef session, CFStringRef propertyKey, CFTypeRef propertyValue)
{
    if (RevenantVTSoftwareSessionOwns((VTDecompressionSessionRef)session))
        return RevenantVTSoftwareSessionSetProperty((VTDecompressionSessionRef)session, propertyKey, propertyValue);
    RevenantVTSetPropertyFunction set = (RevenantVTSetPropertyFunction)RevenantVTSystemSymbol("VTSessionSetProperty");
    return set ? set(session, propertyKey, propertyValue) : kVTPropertyNotSupportedErr;
}

OSStatus BACKPORT_IMPL(VTSessionCopyProperty)(VTSessionRef session, CFStringRef propertyKey, CFAllocatorRef allocator, void *propertyValueOut)
{
    if (RevenantVTSoftwareSessionOwns((VTDecompressionSessionRef)session))
        return RevenantVTSoftwareSessionCopyProperty((VTDecompressionSessionRef)session, propertyKey, allocator, (CFTypeRef *)propertyValueOut);
    RevenantVTCopyPropertyFunction copy = (RevenantVTCopyPropertyFunction)RevenantVTSystemSymbol("VTSessionCopyProperty");
    return copy ? copy(session, propertyKey, allocator, propertyValueOut) : kVTPropertyNotSupportedErr;
}
