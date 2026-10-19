#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

NSArray<NSUUID *> *AXMFiHearingDevicePairedUUIDs(void)
{
    return @[];
}

AXHearingDeviceEar AXMFiHearingDeviceStreamingEar(void)
{
    return AXHearingDeviceEarNone;
}

BOOL AXSupportsBidirectionalAXMFiHearingDeviceStreaming(void)
{
    return NO;
}
