// Host probe: what macOS CoreMIDI answers for a NULL block and for a protocol that is neither 1.0 nor 2.0.
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        OSStatus s = MIDIClientCreateWithBlock(CFSTR("nullargs"), &client, NULL);
        printf("MIDIClientCreateWithBlock(NULL block): %d\n", (int)s);
        s = MIDIClientCreateWithBlock(CFSTR("nullargs"), &client, ^(const MIDINotification *m) {});
        printf("MIDIClientCreateWithBlock(block): %d\n", (int)s);
        MIDIEndpointRef dst = 0;
        s = MIDIDestinationCreateWithProtocol(client, CFSTR("n-dst"), kMIDIProtocol_1_0, &dst, NULL);
        printf("MIDIDestinationCreateWithProtocol(NULL block): %d\n", (int)s);
        s = MIDIDestinationCreateWithProtocol(client, CFSTR("n-dst2"), 3, &dst, ^(const MIDIEventList *e, void *r) {});
        printf("MIDIDestinationCreateWithProtocol(protocol 3): %d\n", (int)s);
        MIDIPortRef in = 0;
        s = MIDIInputPortCreateWithProtocol(client, CFSTR("n-in"), 3, &in, ^(const MIDIEventList *e, void *r) {});
        printf("MIDIInputPortCreateWithProtocol(protocol 3): %d\n", (int)s);
        MIDIEndpointRef src = 0;
        s = MIDISourceCreateWithProtocol(client, CFSTR("n-src"), 3, &src);
        printf("MIDISourceCreateWithProtocol(protocol 3): %d\n", (int)s);
        s = MIDIInputPortCreateWithBlock(client, CFSTR("n-rb"), &in, NULL);
        printf("MIDIInputPortCreateWithBlock(NULL block): %d\n", (int)s);
    }
    return 0;
}
