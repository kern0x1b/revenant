#import <AVFoundation/AVFoundation.h>
#import <CoreMIDI/MIDIServices.h>
#include <stdio.h>
#include <string.h>
#include "../../../../packages/a/apple-backports/AVFAudio/RevenantMIDIEventList.h"

static int failures = 0;
static int checks = 0;

typedef struct {
    unsigned count;
    unsigned char bytes[32][16];
    UInt32 length[32];
} Sent;

static void recordList(const UInt32 *words, UInt32 wordCount, Sent *sent)
{
    Byte buffer[1024];
    MIDIEventList *list = (MIDIEventList *)buffer;
    MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof(buffer), packet, 0, wordCount, words);
    memset(sent, 0, sizeof *sent);
    RevenantForEachMIDIMessage(list, ^(const uint8_t *bytes, UInt32 length) {
        if (sent->count < 32 && length <= 16) {
            memcpy(sent->bytes[sent->count], bytes, length);
            sent->length[sent->count] = length;
            sent->count++;
        }
    });
}

static void expect(const char *name, const UInt32 *words, UInt32 wordCount, const unsigned char *want, UInt32 wantLength)
{
    checks++;
    Sent sent;
    recordList(words, wordCount, &sent);
    if (wantLength == 0) {
        if (sent.count != 0) {
            printf("FAIL %s: sent %u messages, want none\n", name, sent.count);
            failures++;
        }
        return;
    }
    if (sent.count != 1 || sent.length[0] != wantLength || memcmp(sent.bytes[0], want, wantLength) != 0) {
        printf("FAIL %s: sent %u messages; first is %u bytes %02X %02X %02X ... , want %u bytes\n", name, sent.count,
               sent.count ? sent.length[0] : 0, sent.count ? sent.bytes[0][0] : 0, sent.count ? sent.bytes[0][1] : 0,
               sent.count ? sent.bytes[0][2] : 0, wantLength);
        failures++;
    }
}

static void expectSequence(const char *name, const UInt32 *words, UInt32 wordCount, const unsigned char *want, const UInt32 *lengths, unsigned n)
{
    checks++;
    Sent sent;
    recordList(words, wordCount, &sent);
    unsigned offset = 0;
    int ok = sent.count == n;
    for (unsigned i = 0; ok && i < n; i++) {
        if (sent.length[i] != lengths[i] || memcmp(sent.bytes[i], want + offset, lengths[i]) != 0) {
            ok = 0;
        }
        offset += lengths[i];
    }
    if (!ok) {
        printf("FAIL %s: %u messages, want %u in sequence\n", name, sent.count, n);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        { const UInt32 w[] = {0x20903C64}; const unsigned char e[] = {0x90, 0x3C, 0x64}; expect("type2 note on", w, 1, e, 3); }
        { const UInt32 w[] = {0x20B1077F}; const unsigned char e[] = {0xB1, 0x07, 0x7F}; expect("type2 controller", w, 1, e, 3); }
        { const UInt32 w[] = {0x20C50900}; const unsigned char e[] = {0xC5, 0x09}; expect("type2 program change", w, 1, e, 2); }
        { const UInt32 w[] = {0x20D42100}; const unsigned char e[] = {0xD4, 0x21}; expect("type2 channel pressure", w, 1, e, 2); }

        { const UInt32 w[] = {0x11F80000}; const unsigned char e[] = {0xF8}; expect("type1 timing clock", w, 1, e, 1); }
        { const UInt32 w[] = {0x11F20102}; const unsigned char e[] = {0xF2, 0x01, 0x02}; expect("type1 song position", w, 1, e, 3); }
        { const UInt32 w[] = {0x11F10300}; const unsigned char e[] = {0xF1, 0x03}; expect("type1 time code", w, 1, e, 2); }
        { const UInt32 w[] = {0x11F70000}; expect("type1 end of exclusive is not sent alone", w, 1, NULL, 0); }

        { const UInt32 w[] = {0x40903C00, 0xFFFF0000}; const unsigned char e[] = {0x90, 0x3C, 127}; expect("type4 note on 0xFFFF is 127", w, 2, e, 3); }
        { const UInt32 w[] = {0x40903C00, 0x80000000}; const unsigned char e[] = {0x90, 0x3C, 64}; expect("type4 note on 0x8000 is 64", w, 2, e, 3); }
        { const UInt32 w[] = {0x40903C00, 0x01000000}; const unsigned char e[] = {0x90, 0x3C, 1}; expect("type4 note on 0x0100 is 1", w, 2, e, 3); }
        { const UInt32 w[] = {0x40903C00, 0x00000000}; const unsigned char e[] = {0x90, 0x3C, 1}; expect("type4 note on 0 is 1, not a note off", w, 2, e, 3); }
        { const UInt32 w[] = {0x40803C00, 0x80000000}; const unsigned char e[] = {0x80, 0x3C, 64}; expect("type4 note off 0x8000 is 64", w, 2, e, 3); }
        { const UInt32 w[] = {0x40B30700, 0xFFFFFFFF}; const unsigned char e[] = {0xB3, 0x07, 127}; expect("type4 cc7 0xFFFFFFFF is 127", w, 2, e, 3); }
        { const UInt32 w[] = {0x40B30700, 0x80000000}; const unsigned char e[] = {0xB3, 0x07, 64}; expect("type4 cc7 0x80000000 is 64", w, 2, e, 3); }
        { const UInt32 w[] = {0x40B30700, 0x00000001}; const unsigned char e[] = {0xB3, 0x07, 0}; expect("type4 cc7 1 is 0", w, 2, e, 3); }
        { const UInt32 w[] = {0x40E00000, 0xFFFFFFFF}; const unsigned char e[] = {0xE0, 0x7F, 0x7F}; expect("type4 bend max", w, 2, e, 3); }
        { const UInt32 w[] = {0x40E00000, 0xC0000000}; const unsigned char e[] = {0xE0, 0x00, 0x60}; expect("type4 bend 0xC0000000 is 12288", w, 2, e, 3); }
        { const UInt32 w[] = {0x40E00000, 0x00000000}; const unsigned char e[] = {0xE0, 0x00, 0x00}; expect("type4 bend zero", w, 2, e, 3); }
        { const UInt32 w[] = {0x40C00001, 0x09000203};
          const unsigned char e[] = {0xB0, 0x00, 0x02, 0xB0, 0x20, 0x03, 0xC0, 0x09};
          const UInt32 l[] = {3, 3, 2};
          expectSequence("type4 program with bank", w, 2, e, l, 3); }
        { const UInt32 w[] = {0x40D00000, 0xFFFFFFFF}; const unsigned char e[] = {0xD0, 127}; expect("type4 channel pressure max", w, 2, e, 2); }

        { const UInt32 w[] = {0x30067F7F, 0x04010020};
          const unsigned char e[] = {0xF0, 0x7F, 0x7F, 0x04, 0x01, 0x00, 0x20, 0xF7};
          expect("type3 complete master volume", w, 2, e, 8); }
        { const UInt32 w[] = {0x30167F7F, 0x04010020, 0x30311000, 0x00000000};
          const unsigned char e[] = {0xF0, 0x7F, 0x7F, 0x04, 0x01, 0x00, 0x20, 0x10, 0xF7};
          expect("type3 start and end", w, 4, e, 9); }
        { const UInt32 w[] = {0x30167F7F, 0x04010020};
          expect("type3 start without end is not sent", w, 2, NULL, 0); }
        { const UInt32 w[] = {0x30267F7F, 0x04010020};
          expect("type3 continue without start is not sent", w, 2, NULL, 0); }

        { const UInt32 w[] = {0x00000000, 0x50000000}; expect("types 0 and 5 send nothing", w, 2, NULL, 0); }

        printf("messages checked=%d checks=midi-list-bytes failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}
