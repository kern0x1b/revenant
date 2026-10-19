// Host probe: MIDISendUMPSysex and MIDISendUMPSysex8 on macOS, to a 1.0 and a 2.0 virtual destination. Prints the status
// each call answers, the request's wordsToSend and complete flag after the call, and what each destination receives.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

static volatile int gCompletions;
static void completed(MIDISysexSendRequestUMP *request) { gCompletions++; }
static void record(const char *tag, const MIDIEventList *list) {
    const MIDIEventPacket *p = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++) {
        printf("  %s receives:", tag);
        for (UInt32 w = 0; w < p->wordCount; w++) printf(" %08X", p->words[w]);
        printf("\n");
        p = MIDIEventPacketNext(p);
    }
}
static void run(const char *tag, MIDIEndpointRef dest, UInt32 *words, UInt32 count, int sysex8) {
    MIDISysexSendRequestUMP request;
    memset(&request, 0, sizeof(request));
    request.destination = dest;
    request.words = words;
    request.wordsToSend = count;
    request.completionProc = completed;
    gCompletions = 0;
    OSStatus s = sysex8 ? MIDISendUMPSysex8(&request) : MIDISendUMPSysex(&request);
    usleep(400000);
    printf("%s -> status %d, wordsToSend after %u, complete %d, completions %d\n", tag, (int)s, (unsigned)request.wordsToSend, (int)request.complete, gCompletions);
}
int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("umpsend"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef d1 = 0, d2 = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("ump-d1"), kMIDIProtocol_1_0, &d1, ^(const MIDIEventList *l, void *r) { record("1.0 destination", l); });
        MIDIDestinationCreateWithProtocol(client, CFSTR("ump-d2"), kMIDIProtocol_2_0, &d2, ^(const MIDIEventList *l, void *r) { record("2.0 destination", l); });
        usleep(300000);
        UInt32 sx7[4] = {0x30030102u, 0x03000000u, 0x30310D00u, 0x00000000u};
        run("sysex7 complete 3 bytes, 1.0", d1, sx7, 2, 0);
        run("sysex7 complete 3 bytes, 2.0", d2, sx7, 2, 0);
        UInt32 sx7b[4] = {0x30160102u, 0x03040506u, 0x30310D00u, 0x00000000u};
        run("sysex7 start then end, 2.0", d2, sx7b, 4, 0);
        UInt32 sx8[4] = {0x50010102u, 0x03040506u, 0x07080000u, 0x00000000u};
        run("sysex8 1 packet, 1.0", d1, sx8, 4, 1);
        run("sysex8 1 packet, 2.0", d2, sx8, 4, 1);
        run("sysex7 with bad destination", 0, sx7, 2, 0);
        run("sysex7 with zero words", d2, sx7, 0, 0);
        run("sysex7 with a note word", d2, (UInt32[]){0x40903C00u, 0xFFFF0000u}, 2, 0);
    }
    return 0;
}
