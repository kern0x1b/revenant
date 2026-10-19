#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

static UInt32 gOut[256][4];
static int gOutCount[256];
static volatile int gOutN;

static void record(const MIDIEventList *evt) {
    const MIDIEventPacket *p = &evt->packet[0];
    for (UInt32 i = 0; i < evt->numPackets; i++) {
        int k = __sync_fetch_and_add(&gOutN, 1);
        if (k >= 256) return;
        gOutCount[k] = (int)p->wordCount;
        for (UInt32 w = 0; w < p->wordCount && w < 4; w++) gOut[k][w] = p->words[w];
        p = MIDIEventPacketNext(p);
    }
}

static void send(MIDIPortRef out, MIDIEndpointRef dst, const char *tag, const UInt32 *words) {
    Byte buf[256];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof(buf), p, 1000, 2, words);
    gOutN = 0;
    MIDISendEventList(out, dst, list);
    usleep(300000);
    printf("%-34s", tag);
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
        MIDIClientCreateWithBlock(CFSTR("probe4"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dst = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("p4-dst"), kMIDIProtocol_1_0, &dst, ^(const MIDIEventList *e, void *r) { record(e); });
        MIDIPortRef out = 0;
        MIDIOutputPortCreate(client, CFSTR("p4-out"), &out);
        sleep(1);
        UInt32 v[] = {0x00000000, 0x00800000, 0x02000000, 0x02000001, 0x00000001, 0x01000000, 0x04000000, 0x3F000000 , 0x40000000};
        for (size_t i = 0; i < sizeof(v)/sizeof(v[0]); i++) {
            UInt32 w[2] = {0x40200000, v[i]};
            char tag[64]; snprintf(tag, sizeof tag, "rpn 0,0 value %08X", v[i]);
            send(out, dst, tag, w);
        }
        UInt32 rel[2] = {0x40400000, 0x00400000};
        send(out, dst, "relative rpn 0,0 value 0x00400000", rel);
        UInt32 relN[2] = {0x40500000 | (0x01u << 8) | 0x23, 0x80000000};
        send(out, dst, "relative nrpn 1,35 value 0x80000000", relN);
        UInt32 n1[2] = {0x40903C01, 0x80000000};
        send(out, dst, "note on attr type 1 (pb) v16=0x8000", n1);
        UInt32 n2[2] = {0x40903C00 | 0x02, 0x80000000};
        send(out, dst, "note on attr type 2 (manuf) v16=8000", n2);
        UInt32 nof[2] = {0x40803C00, 0x00000000};
        send(out, dst, "note off v16=0", nof);
        UInt32 pb[2] = {0x40E00003, 0x80000000};
        send(out, dst, "pitch bend with bits in word0", pb);
    }
    return 0;
}
