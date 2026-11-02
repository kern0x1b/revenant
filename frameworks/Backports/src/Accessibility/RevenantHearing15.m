#include "../revenant_impl.h"
#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

NSArray<NSUUID *> *BACKPORT_IMPL(AXMFiHearingDevicePairedUUIDs)(void)
{
    return @[];
}

AXHearingDeviceEar BACKPORT_IMPL(AXMFiHearingDeviceStreamingEar)(void)
{
    return AXHearingDeviceEarNone;
}

BOOL BACKPORT_IMPL(AXSupportsBidirectionalAXMFiHearingDeviceStreaming)(void)
{
    return NO;
}
