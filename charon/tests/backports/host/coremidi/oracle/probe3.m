#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>

static void show(const char *tag, const MIDIEventList *l) {
    printf("%s: numPackets=%u\n", tag, l->numPackets);
    const MIDIEventPacket *p = &l->packet[0];
    for (UInt32 i = 0; i < l->numPackets; i++) {
        printf("   ts=%llu wordCount=%u:", (unsigned long long)p->timeStamp, p->wordCount);
        for (UInt32 w = 0; w < p->wordCount && w < 70; w++) printf(" %08X", p->words[w]);
        printf("\n");
        p = MIDIEventPacketNext(p);
    }
}

int main(void) {
    static Byte b[4096];
    UInt32 w[70];
    for (int i = 0; i < 70; i++) w[i] = 0x20900000 + i;
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 2, w);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 2, w + 2);
        show("A two 2-word adds, same ts 7", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 1, w);
        p = MIDIEventListAdd(l, sizeof(b), p, 8, 1, w + 1);
        p = MIDIEventListAdd(l, sizeof(b), p, 8, 1, w + 2);
        show("B ts 7, 8, 8", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 40, w);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 40, w);
        show("C two 40-word adds, same ts", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, 7, 65, w);
        printf("D 65 words -> %s\n", q ? "accepted" : "NULL");
        show("D 65 words", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, 7, 70, w);
        printf("E 70 words -> %s\n", q ? "accepted" : "NULL");
        show("E 70 words", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        p = MIDIEventListAdd(l, sizeof(b), p, 7, 64, w);
        MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, 7, 1, w);
        printf("F 64 words then 1 word same ts -> %s\n", q ? "accepted" : "NULL");
        show("F", l);
    }
    {
        MIDIEventList *l = (MIDIEventList *)b;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, 7, 0, w);
        printf("G 0 words -> %s numPackets=%u\n", q ? "accepted" : "NULL", l->numPackets);
    }
    {
        Byte small[40];
        MIDIEventList *l = (MIDIEventList *)small;
        MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        int n = 0;
        while (p) { MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(small), p, n * 10, 1, w); if (!q) break; p = q; n++; }
        printf("H 40 bytes, distinct ts: packets=%u\n", l->numPackets);
        l = (MIDIEventList *)small;
        p = MIDIEventListInit(l, kMIDIProtocol_1_0);
        int m = 0;
        while (p) { MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(small), p, 5, 1, w); if (!q) break; p = q; m++; }
        printf("I 40 bytes, same ts: packets=%u words-merged-ok=%d\n", l->numPackets, m);
    }
    return 0;
}
