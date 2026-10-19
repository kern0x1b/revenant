#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
int main(void) {
    MIDIEntityRef e = 0;
    OSStatus s0 = MIDIDeviceNewEntity(0, CFSTR("x"), kMIDIProtocol_1_0, false, 0, 0, &e);
    printf("MIDIDeviceNewEntity(0 device) %d entity=%u\n", (int)s0, (unsigned)e);
    ItemCount n = MIDIGetNumberOfDevices();
    printf("setup devices %lu\n", (unsigned long)n);
    if (n > 0) {
        MIDIDeviceRef d = MIDIGetDevice(0);
        OSStatus s1 = MIDIDeviceNewEntity(d, CFSTR("x"), kMIDIProtocol_1_0, false, 0, 0, &e);
        printf("MIDIDeviceNewEntity(first setup device) %d\n", (int)s1);
    }
    return 0;
}
