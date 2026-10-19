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
