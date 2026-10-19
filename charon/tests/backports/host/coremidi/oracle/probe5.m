// Host probe: SysEx chunking into UMP SysEx7 packets, and a SysEx split across two MIDIPackets.
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
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

static void show(const char *tag) {
    printf("%s:", tag);
    for (int i = 0; i < gOutN; i++) {
        printf(" [");
        for (int w = 0; w < gOutCount[i]; w++) printf("%s%08X", w ? " " : "", gOut[i][w]);
        printf("]");
    }
    printf("  (%d)\n", gOutN);
    fflush(stdout);
}

int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("probe5"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dst = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("p5-dst"), kMIDIProtocol_2_0, &dst, ^(const MIDIEventList *e, void *r) { record(e); });
        MIDIPortRef out = 0;
        MIDIOutputPortCreate(client, CFSTR("p5-out"), &out);
        sleep(1);
        struct { const char *tag; Byte b[16]; int n; } cases[] = {
            {"empty F0 F7", {0xF0, 0xF7}, 2},
            {"6 data bytes", {0xF0, 1, 2, 3, 4, 5, 6, 0xF7}, 8},
            {"7 data bytes", {0xF0, 1, 2, 3, 4, 5, 6, 7, 0xF7}, 9},
            {"12 data bytes", {0xF0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0xF7}, 14},
            {"13 data bytes", {0xF0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 0xF7}, 15},
        };
        for (size_t c = 0; c < sizeof(cases)/sizeof(cases[0]); c++) {
            Byte pb[512];
            MIDIPacketList *pl = (MIDIPacketList *)pb;
            MIDIPacketListAdd(pl, sizeof(pb), MIDIPacketListInit(pl), 0, cases[c].n, cases[c].b);
            gOutN = 0;
            MIDISend(out, dst, pl);
            usleep(300000);
            show(cases[c].tag);
        }
        // Split: F0 01 02 in one packet, 03 04 F7 in the next, same send.
        {
            Byte pb[512];
            MIDIPacketList *pl = (MIDIPacketList *)pb;
            MIDIPacket *pk = MIDIPacketListInit(pl);
            Byte a[3] = {0xF0, 1, 2};
            Byte b[3] = {3, 4, 0xF7};
            pk = MIDIPacketListAdd(pl, sizeof(pb), pk, 0, 3, a);
            MIDIPacketListAdd(pl, sizeof(pb), pk, 0, 3, b);
            gOutN = 0;
            MIDISend(out, dst, pl);
            usleep(300000);
            show("split across packets, same timestamp");
        }
        // Real-time inside a SysEx: F0 01 F8 02 F7.
        {
            Byte pb[512];
            MIDIPacketList *pl = (MIDIPacketList *)pb;
            Byte m[5] = {0xF0, 1, 0xF8, 2, 0xF7};
            MIDIPacketListAdd(pl, sizeof(pb), MIDIPacketListInit(pl), 0, 5, m);
            gOutN = 0;
            MIDISend(out, dst, pl);
            usleep(300000);
            show("clock inside sysex");
        }
        // Running status: 90 3C 7F then 3E 40 (no status byte).
        {
            Byte pb[512];
            MIDIPacketList *pl = (MIDIPacketList *)pb;
            Byte m[6] = {0x90, 0x3C, 0x7F, 0x3E, 0x40, 0x00};
            MIDIPacketListAdd(pl, sizeof(pb), MIDIPacketListInit(pl), 0, 5, m);
            gOutN = 0;
            MIDISend(out, dst, pl);
            usleep(300000);
            show("running status");
        }
    }
    return 0;
}
