#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        OSStatus s = MIDIClientCreateWithBlock(CFSTR("newentity"), &client, ^(const MIDINotification *m) {});
        printf("client %d\n", (int)s);
        MIDIDeviceRef device = 0;
        s = MIDIDeviceCreate(NULL, CFSTR("probe device"), CFSTR("charon"), CFSTR("probe"), &device);
        printf("MIDIDeviceCreate %d\n", (int)s);
        if (s != noErr) return 0;
        MIDIEntityRef entity = 0;
        s = MIDIDeviceNewEntity(device, CFSTR("entity A"), kMIDIProtocol_2_0, false, 1, 2, &entity);
        printf("MIDIDeviceNewEntity(2.0, 1 source, 2 destinations) %d entity=%u\n", (int)s, (unsigned)entity);
        if (s == noErr) {
            ItemCount sources = MIDIEntityGetNumberOfSources(entity), dests = MIDIEntityGetNumberOfDestinations(entity);
            printf("sources %lu destinations %lu\n", (unsigned long)sources, (unsigned long)dests);
            SInt32 protocol = -1;
            OSStatus p = MIDIObjectGetIntegerProperty(entity, CFSTR("protocol"), &protocol);
            printf("protocol property %d (status %d)\n", (int)protocol, (int)p);
            ItemCount n = MIDIDeviceGetNumberOfEntities(device);
            printf("device entities %lu\n", (unsigned long)n);
        }
        MIDIEntityRef embedded = 0;
        s = MIDIDeviceNewEntity(device, CFSTR("entity B"), kMIDIProtocol_1_0, true, 0, 0, &embedded);
        printf("MIDIDeviceNewEntity(1.0, embedded, none) %d\n", (int)s);
        s = MIDIDeviceNewEntity(device, CFSTR("entity C"), 3, false, 0, 0, &embedded);
        printf("MIDIDeviceNewEntity(protocol 3) %d\n", (int)s);
    }
    return 0;
}
