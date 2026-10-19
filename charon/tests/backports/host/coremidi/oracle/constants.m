#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>

static void show(const char *name, CFStringRef value) {
    printf("%s=%s\n", name, value ? [(__bridge NSString *)value UTF8String] : "(null)");
}

int main(void) {
    @autoreleasepool {
        show("before MIDIClientCreate kMIDIPropertyAssociatedEndpoint", kMIDIPropertyAssociatedEndpoint);
        show("before MIDIClientCreate kMIDIPropertyUMPActiveGroupBitmap", kMIDIPropertyUMPActiveGroupBitmap);
        show("before MIDIClientCreate kMIDIPropertyUMPCanTransmitGroupless", kMIDIPropertyUMPCanTransmitGroupless);
        MIDIClientRef client = 0;
        OSStatus status = MIDIClientCreate(CFSTR("charon-constants"), NULL, NULL, &client);
        printf("MIDIClientCreate=%d\n", (int)status);
        show("kMIDIPropertyAssociatedEndpoint", kMIDIPropertyAssociatedEndpoint);
        show("kMIDIPropertyUMPActiveGroupBitmap", kMIDIPropertyUMPActiveGroupBitmap);
        show("kMIDIPropertyUMPCanTransmitGroupless", kMIDIPropertyUMPCanTransmitGroupless);
        show("MIDICIDeviceObjectKey", MIDICIDeviceObjectKey);
        show("MIDICIDeviceWasAddedNotification", MIDICIDeviceWasAddedNotification);
        show("MIDICIDeviceWasRemovedNotification", MIDICIDeviceWasRemovedNotification);
        show("MIDICIProfileObjectKey", MIDICIProfileObjectKey);
        show("MIDICIProfileWasRemovedNotification", MIDICIProfileWasRemovedNotification);
        show("MIDICIProfileWasUpdatedNotification", MIDICIProfileWasUpdatedNotification);
        show("MIDIUMPEndpointObjectKey", MIDIUMPEndpointObjectKey);
        show("MIDIUMPEndpointWasAddedNotification", MIDIUMPEndpointWasAddedNotification);
        show("MIDIUMPEndpointWasRemovedNotification", MIDIUMPEndpointWasRemovedNotification);
        show("MIDIUMPEndpointWasUpdatedNotification", MIDIUMPEndpointWasUpdatedNotification);
        show("MIDIUMPFunctionBlockObjectKey", MIDIUMPFunctionBlockObjectKey);
        show("MIDIUMPFunctionBlockWasUpdatedNotification", MIDIUMPFunctionBlockWasUpdatedNotification);
        MIDIClientDispose(client);
    }
    return 0;
}
