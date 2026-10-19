// Batched host oracle: macOS CoreMIDI's MIDI 1.0 <-> 2.0 translation of many messages at once.
// Each message is one packet of one event list, at its own timestamp, sent to a virtual destination;
// the destination's receive block gets the packets back, and packet i of the output is the answer to
// message i. A count mismatch is printed, and that batch is then sent one message at a time.
// argv[1]: "down" (MIDI 2.0 input to a 1.0 destination) or "up" (MIDI 1.0 UMP input to a 2.0 destination).
// Output lines: "<tag> <input words> -> <output words or none>".
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dispatch/dispatch.h>

static UInt32 gOutWords[300000][4];
static int gOutCount[300000];
static volatile int gOutN;

// Every packet the destination receives, in order, across however many callbacks it takes.
static void record(const MIDIEventList *evt) {
    const MIDIEventPacket *p = &evt->packet[0];
    for (UInt32 i = 0; i < evt->numPackets; i++) {
        int k = __sync_fetch_and_add(&gOutN, 1);
        if (k >= 300000) return;
        gOutCount[k] = (int)p->wordCount;
        for (UInt32 w = 0; w < p->wordCount && w < 4; w++) gOutWords[k][w] = p->words[w];
        p = MIDIEventPacketNext(p);
    }
}

// One batch: count messages, each of 'words' words, in buf (stride 2 words max).
static void print_packets(const MIDIEventList *l) {
    const MIDIEventPacket *p = &l->packet[0];
    for (UInt32 i = 0; i < l->numPackets; i++) {
        printf(" [");
        for (UInt32 w = 0; w < p->wordCount; w++) printf("%s%08X", w ? " " : "", p->words[w]);
        printf("]");
        p = MIDIEventPacketNext(p);
    }
}

static dispatch_semaphore_t gSem;

static void batch(MIDIPortRef out, MIDIEndpointRef dst, MIDIProtocolID proto, const char **tags,
                  const UInt32 (*msgs)[2], const int *lens, int count) {
    static Byte buf[1 << 20];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, proto);
    for (int i = 0; i < count; i++) {
        p = MIDIEventListAdd(list, sizeof(buf), p, (MIDITimeStamp)(i + 1) * 1000, lens[i], msgs[i]);
        if (!p) { fprintf(stderr, "list full at %d\n", i); exit(2); }
    }
    gOutN = 0;
    MIDISendEventList(out, dst, list);
    int waited = 0, last = -1, quiet = 0;
    while (waited < 4000) {
        usleep(10000);
        waited += 10;
        if (gOutN >= count) { if (gOutN == last) { if (++quiet >= 20) break; } else { quiet = 0; } }
        last = gOutN;
    }
    int got = gOutN;
    if (got != count) printf("MISMATCH count=%d got=%d\n", count, got);
    for (int i = 0; i < count; i++) {
        printf("%s in:", tags[i]);
        for (int w = 0; w < lens[i]; w++) printf(" %08X", msgs[i][w]);
        printf(" ->");
        if (i < got) {
            for (int w = 0; w < gOutCount[i]; w++) printf(" %08X", gOutWords[i][w]);
        } else {
            printf(" none");
        }
        printf("\n");
    }
    fflush(stdout);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        const char *mode = argc > 1 ? argv[1] : "down";
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("batch"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dst = 0;
        gSem = NULL;
        int up = strcmp(mode, "up") == 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("batch-dst"), up ? kMIDIProtocol_2_0 : kMIDIProtocol_1_0, &dst,
            ^(const MIDIEventList *evt, void *ref) { record(evt); });
        MIDIPortRef out = 0;
        MIDIOutputPortCreate(client, CFSTR("batch-out"), &out);
        sleep(1);
        // Cases: a flat table of (tag, words, length), sent in chunks of 256.
        static UInt32 msgs[200000][2];
        static int lens[200000];
        static const char *tags[200000];
        static char tagbuf[200000][48];
        int n = 0;
        if (!up) {
            // MIDI 2.0 -> 1.0. Velocities over the whole 16-bit range (note on and note off).
            for (UInt32 v = 0; v < 65536; v += 1) {
                msgs[n][0] = 0x40903C00; msgs[n][1] = v << 16; lens[n] = 2;
                snprintf(tagbuf[n], 48, "non v16=%05u", v); tags[n] = tagbuf[n]; n++;
            }
            // Controller values over 32 bits: every 8th value, plus the corners.
            for (UInt64 v = 0; v <= 0xFFFFFFFFull; v += 0x80000ull) {
                msgs[n][0] = 0x40B00007; msgs[n][1] = (UInt32)v; lens[n] = 2;
                snprintf(tagbuf[n], 48, "cc7 v32=%08llX", (unsigned long long)v); tags[n] = tagbuf[n]; n++;
            }
            // Pitch bend over 32 bits (every 0x40000), and the channel pressure with the same values.
            for (UInt64 v = 0; v <= 0xFFFFFFFFull; v += 0x40000ull) {
                msgs[n][0] = 0x40E00000; msgs[n][1] = (UInt32)v; lens[n] = 2;
                snprintf(tagbuf[n], 48, "pb v32=%08llX", (unsigned long long)v); tags[n] = tagbuf[n]; n++;
                msgs[n][0] = 0x40D00000; msgs[n][1] = (UInt32)v; lens[n] = 2;
                snprintf(tagbuf[n], 48, "cp v32=%08llX", (unsigned long long)v); tags[n] = tagbuf[n]; n++;
            }
            // Poly pressure, program change words.
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x40A03C00; msgs[n][1] = v << 25; lens[n] = 2;
                snprintf(tagbuf[n], 48, "pp v32=%08X", v << 25); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 v = 0; v < 256; v++) {
                msgs[n][0] = 0x40C00000; msgs[n][1] = (v << 24); lens[n] = 2;
                snprintf(tagbuf[n], 48, "pc v8=%02X", v); tags[n] = tagbuf[n]; n++;
            }
        } else {
            // MIDI 1.0 -> 2.0, one packet each (the 1.0 receive side is not used here).
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x20903C00 | v; msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "non1 v7=%03u", v); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x20B00700 | v; msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "cc1 v7=%03u", v); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x20D00000 | v; msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "cp1 v7=%03u", v); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x20A03C00 | v; msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "pp1 v7=%03u", v); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 lsb = 0; lsb < 128; lsb += 1) {
                msgs[n][0] = 0x20E00000 | lsb; msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "pb1 lsb=%03u", lsb); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 msb = 0; msb < 128; msb++) {
                msgs[n][0] = 0x20E00000 | (msb << 8); msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "pb1 msb=%03u", msb); tags[n] = tagbuf[n]; n++;
            }
            for (UInt32 v = 0; v < 128; v++) {
                msgs[n][0] = 0x20C00000 | (v << 8); msgs[n][1] = 0; lens[n] = 1;
                snprintf(tagbuf[n], 48, "pc1 v7=%03u", v); tags[n] = tagbuf[n]; n++;
            }
        }
        for (int start = 0; start < n; start += 256) {
            int count = n - start < 256 ? n - start : 256;
            batch(out, dst, up ? kMIDIProtocol_1_0 : kMIDIProtocol_2_0, &tags[start], &msgs[start], &lens[start], count);
        }
        printf("cases=%d\n", n);
    }
    return 0;
}
