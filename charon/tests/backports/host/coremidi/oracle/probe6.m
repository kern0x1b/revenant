// Host probe: running status and a SysEx left open, each alone in a fresh process (argv[1] picks the case).
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static UInt32 gOut[64][4];
static int gOutCount[64];
static volatile int gOutN;

static void record(const MIDIEventList *evt) {
    const MIDIEventPacket *p = &evt->packet[0];
    for (UInt32 i = 0; i < evt->numPackets; i++) {
        int k = __sync_fetch_and_add(&gOutN, 1);
        if (k >= 64) return;
        gOutCount[k] = (int)p->wordCount;
        for (UInt32 w = 0; w < p->wordCount && w < 4; w++) gOut[k][w] = p->words[w];
        p = MIDIEventPacketNext(p);
    }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        const char *which = argc > 1 ? argv[1] : "running";
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("probe6"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dst = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("p6-dst"), kMIDIProtocol_2_0, &dst, ^(const MIDIEventList *e, void *r) { record(e); });
        MIDIPortRef out = 0;
        MIDIOutputPortCreate(client, CFSTR("p6-out"), &out);
        sleep(1);
        Byte pb[512];
        MIDIPacketList *pl = (MIDIPacketList *)pb;
        Byte m[8];
        int n = 0;
        if (strcmp(which, "running") == 0) {          // 90 3C 7F, then running status 3E 40
            Byte x[5] = {0x90, 0x3C, 0x7F, 0x3E, 0x40};
            memcpy(m, x, 5); n = 5;
        } else if (strcmp(which, "running2") == 0) {  // 90 3C 7F 40 (running status, two notes)
            Byte x[6] = {0x90, 0x3C, 0x7F, 0x40, 0x7F, 0x00};
            memcpy(m, x, 6); n = 5;
        } else if (strcmp(which, "open") == 0) {      // F0 01 02 left open (no F7)
            Byte x[3] = {0xF0, 1, 2};
            memcpy(m, x, 3); n = 3;
        } else if (strcmp(which, "clock-in-sysex-end") == 0) {  // F0 01 F8 F7
            Byte x[4] = {0xF0, 1, 0xF8, 0xF7};
            memcpy(m, x, 4); n = 4;
        }
        MIDIPacketListAdd(pl, sizeof(pb), MIDIPacketListInit(pl), 0, n, m);
        MIDISend(out, dst, pl);
        usleep(400000);
        printf("%s:", which);
        for (int i = 0; i < gOutN; i++) {
            printf(" [");
            for (int w = 0; w < gOutCount[i]; w++) printf("%s%08X", w ? " " : "", gOut[i][w]);
            printf("]");
        }
        printf("  (%d)\n", gOutN);
    }
    return 0;
}
