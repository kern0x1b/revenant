// Host probes for the cases the batch oracle cannot express: lists with several packets, bank select,
// RPN/NRPN, the MIDIEventList builders' limits and MIDIEventListForEachEvent's visitor.
// Each block prints what macOS does; nothing here is a claim about the port.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static UInt32 gOut[4096][4];
static int gOutCount[4096];
static volatile int gOutN;

static void record(const MIDIEventList *evt) {
    const MIDIEventPacket *p = &evt->packet[0];
    for (UInt32 i = 0; i < evt->numPackets; i++) {
        int k = __sync_fetch_and_add(&gOutN, 1);
        if (k >= 4096) return;
        gOutCount[k] = (int)p->wordCount;
        for (UInt32 w = 0; w < p->wordCount && w < 4; w++) gOut[k][w] = p->words[w];
        p = MIDIEventPacketNext(p);
    }
}

static void send_and_print(MIDIPortRef out, MIDIEndpointRef dst, const char *tag, MIDIProtocolID proto, const UInt32 *words, int count) {
    static Byte buf[4096];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, proto);
    for (int i = 0; i < count; i++) {
        // one packet per message, timestamps apart
        p = MIDIEventListAdd(list, sizeof(buf), p, (MIDITimeStamp)(i + 1) * 1000, 2, &words[2 * i]);
    }
    gOutN = 0;
    MIDISendEventList(out, dst, list);
    usleep(400000);
    printf("%s:", tag);
    int n = gOutN;
    for (int i = 0; i < n && i < 4096; i++) {
        printf(" [");
        for (int w = 0; w < gOutCount[i]; w++) printf("%s%08X", w ? " " : "", gOut[i][w]);
        printf("]");
    }
    printf("  (%d packets)\n", n);
    fflush(stdout);
}

int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("probe2"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dst2 = 0, dst1 = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("p2-dst2"), kMIDIProtocol_2_0, &dst2, ^(const MIDIEventList *e, void *r) { record(e); });
        MIDIPortRef out = 0;
        MIDIOutputPortCreate(client, CFSTR("p2-out"), &out);
        sleep(1);
        printf("== program change with bank valid, 2.0 -> 1.0 destination\n");
        MIDIDestinationCreateWithProtocol(client, CFSTR("p2-dst1"), kMIDIProtocol_1_0, &dst1, ^(const MIDIEventList *e, void *r) { record(e); });
        sleep(1);
        UInt32 pcb[2] = {0x40C00001, 0x05000A03};   // bank valid, program 5, bank MSB 0x0A? (word1 bits 15-8 MSB, 7-0 LSB)
        send_and_print(out, dst1, "pc bank-valid msb=0x0A lsb=0x03 prog=5", kMIDIProtocol_2_0, pcb, 1);
        UInt32 pcb2[2] = {0x40C00001, 0x05000A03};
        (void)pcb2;
        printf("== RPN 0,0 value 0x00400000 (word0 0x40200000), 2.0 -> 1.0\n");
        UInt32 rpn[2] = {0x40200000, 0x00400000};
        send_and_print(out, dst1, "rpn 0,0", kMIDIProtocol_2_0, rpn, 1);
        UInt32 nrpn[2] = {0x40300000 | (0x01u << 8) | 0x23, 0x00400000};
        send_and_print(out, dst1, "nrpn 1,35", kMIDIProtocol_2_0, nrpn, 1);
        UInt32 rpnr[2] = {0x40200000 | (0x00u << 8) | 0x00, 0x00000000};
        send_and_print(out, dst1, "rpn 0,0 value 0", kMIDIProtocol_2_0, rpnr, 1);
        UInt32 rpnhi[2] = {0x40200000 | (0x00u << 8) | 0x00, 0xFFFFFFFF};
        send_and_print(out, dst1, "rpn 0,0 value FFFFFFFF", kMIDIProtocol_2_0, rpnhi, 1);
        printf("== per-note pitch bend, per-note management, assignable controllers, 2.0 -> 1.0\n");
        UInt32 pnpb[2] = {0x40603C00, 0x40000000};
        send_and_print(out, dst1, "per-note pitch bend", kMIDIProtocol_2_0, pnpb, 1);
        UInt32 pnm[2] = {0x40F03C00, 0x00000001};
        send_and_print(out, dst1, "per-note management detach", kMIDIProtocol_2_0, pnm, 1);
        UInt32 acc[2] = {0x40103C00, 0x40000000};
        send_and_print(out, dst1, "relative RPN?(0x4010)", kMIDIProtocol_2_0, acc, 1);
        UInt32 anrpn[2] = {0x40100000 | (0x3Cu << 8) | 0x01, 0x40000000};
        send_and_print(out, dst1, "assignable-nrpn 0x4010 idx 0x01", kMIDIProtocol_2_0, anrpn, 1);
        printf("== MIDI 1.0 CC sequences into a 2.0 destination (RPN 0,0 bytes)\n");
        {
            Byte pb[256];
            MIDIPacketList *pl = (MIDIPacketList *)pb;
            MIDIPacket *pk = MIDIPacketListInit(pl);
            Byte m1[3] = {0xB0, 101, 0}; pk = MIDIPacketListAdd(pl, sizeof(pb), pk, 0, 3, m1);
            Byte m2[3] = {0xB0, 100, 0}; pk = MIDIPacketListAdd(pl, sizeof(pb), pk, 1000, 3, m2);
            Byte m3[3] = {0xB0, 6, 12}; pk = MIDIPacketListAdd(pl, sizeof(pb), pk, 2000, 3, m3);
            gOutN = 0;
            MIDISend(out, dst2, pl);
            usleep(400000);
            printf("cc101/100/6 bytes into 2.0 dest:");
            for (int i = 0; i < gOutN; i++) {
                printf(" [");
                for (int w = 0; w < gOutCount[i]; w++) printf("%s%08X", w ? " " : "", gOut[i][w]);
                printf("]");
            }
            printf("  (%d packets)\n", gOutN);
        }
        printf("== MIDIEventListAdd: same timestamp, overflow, 64-word limit\n");
        {
            Byte b[256];
            MIDIEventList *l = (MIDIEventList *)b;
            MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
            UInt32 w[1] = {0x20903C7F};
            p = MIDIEventListAdd(l, sizeof(b), p, 5, 1, w);
            p = p ? MIDIEventListAdd(l, sizeof(b), p, 5, 1, w) : NULL;
            printf("same ts twice: packets=%u ptr=%s\n", l->numPackets, p ? "ok" : "NULL");
        }
        {
            Byte b[64];
            MIDIEventList *l = (MIDIEventList *)b;
            MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
            UInt32 w[1] = {0x20903C7F};
            int n = 0;
            while (p) { MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, n, 1, w); if (!q) break; p = q; n++; }
            printf("64-byte buffer: packets=%u, then ptr %s\n", l->numPackets, p ? "non-null" : "NULL");
        }
        {
            Byte b[1024];
            MIDIEventList *l = (MIDIEventList *)b;
            MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
            UInt32 w[65];
            for (int i = 0; i < 65; i++) w[i] = 0x30000000;
            MIDIEventPacket *q = MIDIEventListAdd(l, sizeof(b), p, 0, 65, w);
            printf("65 words: %s, numPackets=%u\n", q ? "accepted" : "NULL", l->numPackets);
            q = MIDIEventListAdd(l, sizeof(b), p, 0, 64, w);
            printf("64 words: %s\n", q ? "accepted" : "NULL");
        }
        {
            Byte b[256];
            MIDIEventList *l = (MIDIEventList *)b;
            MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_2_0);
            UInt32 w[1] = {0x20903C7F};
            p = MIDIEventListAdd(l, sizeof(b), p, 0, 1, w);
            printf("protocol field after init 2.0: %d\n", (int)l->protocol);
            printf("first packet timestamp=%llu wordCount=%u\n", (unsigned long long)l->packet[0].timeStamp, l->packet[0].wordCount);
        }
        printf("== MIDIEventListInit on a list of 0 bytes\n");
        {
            Byte b[16];
            MIDIEventList *l = (MIDIEventList *)b;
            MIDIEventPacket *p = MIDIEventListInit(l, kMIDIProtocol_1_0);
            printf("init result offset=%ld numPackets=%u\n", (long)((Byte *)p - (Byte *)l), l->numPackets);
        }
        printf("== sizes: MIDIEventList=%zu MIDIEventPacket=%zu MIDIUniversalMessage=%zu\n", sizeof(MIDIEventList), sizeof(MIDIEventPacket), sizeof(MIDIUniversalMessage));
        printf("== constants\n");
        printf("kMIDIProtocol_1_0=%d kMIDIProtocol_2_0=%d\n", kMIDIProtocol_1_0, kMIDIProtocol_2_0);
        printf("kMIDIPropertyProtocolID=%s\n", [(__bridge NSString *)kMIDIPropertyProtocolID UTF8String]);
        printf("kMIDIPropertyNameConfigurationDictionary=%s\n", [(__bridge NSString *)kMIDIPropertyNameConfigurationDictionary UTF8String]);
    }
    return 0;
}
