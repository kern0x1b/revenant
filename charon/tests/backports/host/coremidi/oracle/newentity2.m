// FORBIDDEN ON THE HOST. Do not run: with the first setup device it added an entity "x" (protocol 1) to the device "Network"
// and left it there (reverted on 2026-10-10 with MIDIDeviceRemoveEntity; see facts/CoreMIDI/Devices.md). It is kept as the
// record of the measurement. Probes must not create or edit persistent host MIDI objects.
// Host probe: MIDIDeviceNewEntity on the devices an application can name: none (0), and the first device of the setup.
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
