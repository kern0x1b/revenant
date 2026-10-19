// FORBIDDEN ON THE HOST. Do not run: MIDIBluetoothDriverActivateAllConnections sets the Bluetooth driver's "activate all
// devices" flag in the host's MIDI setup (the flag is 1 in the live setup, unexplained: coordination/wave-2026-10-03/
// v-coremidi-report.md, "Host state"). It is kept as the record of the measurement; probes must not change host MIDI state.
// Host probe: what the Bluetooth driver calls return on macOS, with no device and with an unknown identifier.
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
int main(void) {
    OSStatus a = MIDIBluetoothDriverActivateAllConnections();
    printf("MIDIBluetoothDriverActivateAllConnections -> %d\n", (int)a);
    OSStatus d = MIDIBluetoothDriverDisconnect(CFSTR("00000000-0000-0000-0000-000000000000"));
    printf("MIDIBluetoothDriverDisconnect(unknown) -> %d\n", (int)d);
    OSStatus d2 = MIDIBluetoothDriverDisconnect(CFSTR(""));
    printf("MIDIBluetoothDriverDisconnect(empty) -> %d\n", (int)d2);
    return 0;
}
