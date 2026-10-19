#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>

static AXHearingDeviceEar CharonNoStreamingEar(void) { return AXHearingDeviceEarNone; }
static BOOL CharonNoBidirectionalStreaming(void) { return NO; }
static NSUInteger CharonNoPairedHearingDevices(void) { return 0; }

int main(void)
{
    @autoreleasepool {
        (void)AXMFiHearingDevicePairedUUIDs();
        (void)AXMFiHearingDeviceStreamingEar();
        (void)AXSupportsBidirectionalAXMFiHearingDeviceStreaming();
        printf("hearing answers compiled: paired=%lu ear=%lu bidirectional=%d\n",
               (unsigned long)CharonNoPairedHearingDevices(),
               (unsigned long)CharonNoStreamingEar(),
               CharonNoBidirectionalStreaming() ? 1 : 0);
    }
    return 0;
}
