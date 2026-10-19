// Host probe: what a MIDI 1.0 protocol destination of this process receives for type-1 (system) UMP words that are
// invalid or valid. Two virtual destinations are made: one with MIDIDestinationCreateWithProtocol(kMIDIProtocol_1_0)
// whose block gets MIDIEventLists (the UMP words), and one with the legacy MIDIDestinationCreateWithBlock whose
// block gets MIDIPacketLists (the MIDI 1.0 bytes). An output port of this process sends each word alone, in its own
// MIDISendEventList call, to each destination. Each line prints the word, then what each block received, or NONE.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

static NSObject *gLock;
static NSMutableString *gEvtCap;
static NSMutableString *gLegCap;
static MIDIPortRef gOut;
static MIDIEndpointRef gDestEvt, gDestLeg;

static void clearCaps(void) {
    @synchronized (gLock) {
        gEvtCap = [NSMutableString string];
        gLegCap = [NSMutableString string];
    }
}

static NSString *takeEvt(void) {
    @synchronized (gLock) { return [gEvtCap length] ? [gEvtCap copy] : @"NONE"; }
}

static NSString *takeLeg(void) {
    @synchronized (gLock) { return [gLegCap length] ? [gLegCap copy] : @"NONE"; }
}

static void sendWord(const char *label, UInt32 word) {
    Byte buf[64];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_1_0);
    MIDIEventListAdd(list, sizeof(buf), p, 0, 1, &word);

    clearCaps();
    OSStatus s1 = MIDISendEventList(gOut, gDestEvt, list);
    usleep(400000);
    NSString *evt = takeEvt();

    clearCaps();
    OSStatus s2 = MIDISendEventList(gOut, gDestLeg, list);
    usleep(400000);
    NSString *leg = takeLeg();

    printf("%-10s word %08X | status evt %d leg %d\n", label, (unsigned)word, (int)s1, (int)s2);
    printf("    eventlist block (UMP words): %s\n", [evt UTF8String]);
    printf("    packetlist block (MIDI 1.0 bytes): %s\n", [leg UTF8String]);
}

int main(void) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        gLock = [[NSObject alloc] init];
        clearCaps();

        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("ump-invalid-system"), &client, ^(const MIDINotification *m) {});

        MIDIDestinationCreateWithProtocol(client, CFSTR("inv-evt-1.0"), kMIDIProtocol_1_0, &gDestEvt,
            ^(const MIDIEventList *evtlist, void *srcConnRefCon) {
                NSMutableString *s = [NSMutableString string];
                const MIDIEventPacket *p = &evtlist->packet[0];
                for (UInt32 i = 0; i < evtlist->numPackets; i++) {
                    [s appendFormat:@" [packet %u words", (unsigned)i];
                    for (UInt32 w = 0; w < p->wordCount; w++) [s appendFormat:@" %08X", (unsigned)p->words[w]];
                    [s appendString:@"]"];
                    p = MIDIEventPacketNext(p);
                }
                @synchronized (gLock) { [gEvtCap appendString:s]; }
            });

        MIDIDestinationCreateWithBlock(client, CFSTR("inv-leg"), &gDestLeg,
            ^(const MIDIPacketList *pktlist, void *srcConnRefCon) {
                NSMutableString *s = [NSMutableString string];
                const MIDIPacket *p = &pktlist->packet[0];
                for (UInt32 i = 0; i < pktlist->numPackets; i++) {
                    [s appendString:@" [bytes"];
                    for (UInt32 b = 0; b < p->length; b++) [s appendFormat:@" %02X", (unsigned)p->data[b]];
                    [s appendString:@"]"];
                    p = MIDIPacketNext(p);
                }
                @synchronized (gLock) { [gLegCap appendString:s]; }
            });

        MIDIOutputPortCreate(client, CFSTR("inv-out"), &gOut);
        usleep(300000);

        sendWord("F0", 0x10F00000u);
        sendWord("F7", 0x10F70000u);
        sendWord("data45", 0x10450000u);
        sendWord("90 no data", 0x10900000u);
        sendWord("MTC", 0x10F10000u);
        sendWord("clock", 0x10F80000u);
        sendWord("F4", 0x10F40000u);
        sendWord("F5", 0x10F50000u);
        sendWord("tune", 0x10F60000u);
        sendWord("active", 0x10FE0000u);
        sendWord("SPP zero", 0x10F20000u);

        MIDIPortDispose(gOut);
        MIDIEndpointDispose(gDestEvt);
        MIDIEndpointDispose(gDestLeg);
        MIDIClientDispose(client);
    }
    return 0;
}
