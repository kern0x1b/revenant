#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

static AXHearingDeviceEar RevenantNoStreamingEar(void) { return AXHearingDeviceEarNone; }
static BOOL RevenantNoBidirectionalStreaming(void) { return NO; }
static NSUInteger RevenantNoPairedHearingDevices(void) { return 0; }

int main(void)
{
    @autoreleasepool {
        (void)AXMFiHearingDevicePairedUUIDs();
        (void)AXMFiHearingDeviceStreamingEar();
        (void)AXSupportsBidirectionalAXMFiHearingDeviceStreaming();
        printf("hearing answers compiled: paired=%lu ear=%lu bidirectional=%d\n",
               (unsigned long)RevenantNoPairedHearingDevices(),
               (unsigned long)RevenantNoStreamingEar(),
               RevenantNoBidirectionalStreaming() ? 1 : 0);
    }
    return 0;
}
