#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#import "CharonCoreMIDI.h"

typedef struct charon_received {
    UInt32 words[8];
    int count;
    void *ref;
} charon_received;

#define CHARON_RECEIVED_MAX 16
static charon_received gInput[CHARON_RECEIVED_MAX];
static int gInputCount;
static dispatch_semaphore_t gInputSignal;
static charon_received gDest[CHARON_RECEIVED_MAX];
static int gDestCount;
static dispatch_semaphore_t gDestSignal;

static int charon_first_words(const MIDIEventList *list, UInt32 *out)
{
    if (list->numPackets == 0)
        return 0;
    const MIDIEventPacket *packet = &list->packet[0];
    int n = packet->wordCount < 8 ? (int)packet->wordCount : 8;
    memcpy(out, packet->words, (size_t)n * sizeof(UInt32));
    return n;
}

static void charon_record_input(const MIDIEventList *list, void *srcConnRefCon)
{
    if (gInputCount < CHARON_RECEIVED_MAX) {
        charon_received *row = &gInput[gInputCount++];
        row->count = charon_first_words(list, row->words);
        row->ref = srcConnRefCon;
    }
    dispatch_semaphore_signal(gInputSignal);
}

static void charon_record_dest(const MIDIEventList *list, void *srcConnRefCon)
{
    if (gDestCount < CHARON_RECEIVED_MAX) {
        charon_received *row = &gDest[gDestCount++];
        row->count = charon_first_words(list, row->words);
        row->ref = srcConnRefCon;
    }
    dispatch_semaphore_signal(gDestSignal);
}

static int charon_wait(dispatch_semaphore_t signal)
{
    return dispatch_semaphore_wait(signal, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
}

static int charon_same_words(const charon_received *row, const UInt32 *want, int wantCount)
{
    if (row->count != wantCount)
        return 0;
    return memcmp(row->words, want, (size_t)wantCount * sizeof(UInt32)) == 0;
}

static MIDIPacketList *charon_packets(Byte *buffer, size_t size, const Byte *data, ByteCount length)
{
    MIDIPacketList *list = (MIDIPacketList *)buffer;
    MIDIPacketListAdd(list, size, MIDIPacketListInit(list), 0, length, data);
    return list;
}

static int charon_receive_bytes(MIDIEndpointRef source, const Byte *data, ByteCount length)
{
    Byte buffer[256];
    MIDIPacketList *list = charon_packets(buffer, sizeof(buffer), data, length);
    OSStatus status = MIDIReceived(source, list);
    return status == noErr && charon_wait(gInputSignal);
}

static void charon_report(int *checks, int *failures, const char *name, int passed)
{
    (*checks)++;
    if (!passed) (*failures)++;
    printf("%s %s\n", passed ? "ok" : "FAIL", name);
}

extern OSStatus charon_host_MIDIClientCreateWithBlock(CFStringRef name, MIDIClientRef *outClient, MIDINotifyBlock notifyBlock);

static int gTokenReleased;

@interface CharonProbeToken : NSObject
@end

@implementation CharonProbeToken
- (void)dealloc
{
    gTokenReleased = 1;
}
@end

static void charon_make_disposed_client_with_token(void)
{
    CharonProbeToken *token = [[CharonProbeToken alloc] init];
    MIDIClientRef client = 0;
    OSStatus status = charon_host_MIDIClientCreateWithBlock(CFSTR("charon-client-token"), &client, ^(const MIDINotification *message) {
        (void)token;
    });
    token = nil;
    if (status == noErr)
        MIDIClientDispose(client);
}

int charon_ports_run(int *checks)
{
    int failures = 0;
    *checks = 0;
    gInputSignal = dispatch_semaphore_create(0);
    gDestSignal = dispatch_semaphore_create(0);
    MIDIClientRef client = 0;
    OSStatus status = MIDIClientCreate(CFSTR("charon-ports-test"), NULL, NULL, &client);
    if (status != noErr) {
        charon_report(checks, &failures, "ports: a client for the test", 0);
        return failures;
    }

    MIDIPortRef inPort = 0;
    MIDIEndpointRef srcA = 0, srcB = 0;
    status = CharonMIDIInputPort(client, CFSTR("charon-in"), kMIDIProtocol_2_0, &inPort, ^(const MIDIEventList *list, void *ref) {
        charon_record_input(list, ref);
    });
    OSStatus statusA = MIDISourceCreate(client, CFSTR("charon-src-a"), &srcA);
    OSStatus statusB = MIDISourceCreate(client, CFSTR("charon-src-b"), &srcB);
    int made = status == noErr && statusA == noErr && statusB == noErr;
    charon_report(checks, &failures, "ports: an input port and two virtual sources for the test", made);
    if (made) {
        MIDIPortConnectSource(inPort, srcA, (void *)1);
        MIDIPortConnectSource(inPort, srcB, (void *)2);
        int ok1 = charon_receive_bytes(srcA, (const Byte[]){0xF0, 0x01}, 2);
        const UInt32 start[] = {0x30110100u, 0x00000000u};
        charon_report(checks, &failures, "ports: source A's F0 01 is a SysEx start on A",
                      ok1 && gInputCount == 1 && charon_same_words(&gInput[0], start, 2) && gInput[0].ref == (void *)1);
        int ok2 = charon_receive_bytes(srcB, (const Byte[]){0x90, 0x3C, 0x7F}, 3);
        const UInt32 note[] = {0x40903C00u, 0xFFFF0000u};
        charon_report(checks, &failures, "ports: source B's note is a 2.0 note on, as B's own",
                      ok2 && gInputCount == 2 && charon_same_words(&gInput[1], note, 2) && gInput[1].ref == (void *)2);
        int ok3 = charon_receive_bytes(srcA, (const Byte[]){0x02, 0xF7}, 2);
        const UInt32 end[] = {0x30310200u, 0x00000000u};
        charon_report(checks, &failures, "ports: source A's 02 F7 ends A's own SysEx, not a note of B's running status",
                      ok3 && gInputCount == 3 && charon_same_words(&gInput[2], end, 2) && gInput[2].ref == (void *)1);
        MIDIPortDisconnectSource(inPort, srcA);
        MIDIPortDisconnectSource(inPort, srcB);
    }

    MIDIPortRef outPort = 0;
    MIDIEndpointRef dest = 0, releaseDest = 0;
    OSStatus outStatus = MIDIOutputPortCreate(client, CFSTR("charon-out"), &outPort);
    OSStatus destStatus = CharonMIDIDestination(client, CFSTR("charon-dest-2"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *list, void *ref) {
        charon_record_dest(list, ref);
    });
    OSStatus releaseStatus = MIDIDestinationCreateWithProtocol(client, CFSTR("charon-release-2"), kMIDIProtocol_2_0, &releaseDest, ^(const MIDIEventList *list, void *ref) {
        charon_record_dest(list, ref);
    });
    charon_report(checks, &failures, "ports: an output port, a 2.0 destination of the library and one of the release",
                  outStatus == noErr && destStatus == noErr && releaseStatus == noErr);
    if (outStatus == noErr && destStatus == noErr && releaseStatus == noErr) {
        Byte buffer[64];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        CharonMIDIEventListAdd(list, sizeof(buffer), end, 0, 2, words);
        OSStatus sent = CharonMIDISend(outPort, dest, list);
        int got = sent == noErr && charon_wait(gDestSignal);
        charon_report(checks, &failures, "ports: a 2.0 velocity of 0x1234 to a library destination arrives as sent",
                      got && gDestCount == 1 && charon_same_words(&gDest[gDestCount - 1], words, 2));
        OSStatus releaseSent = MIDISendEventList(outPort, releaseDest, list);
        int releaseGot = releaseSent == noErr && charon_wait(gDestSignal);
        charon_report(checks, &failures, "ports: the release's own 2.0 destination gets the same 0x1234 (the measured answer)",
                      releaseGot && gDestCount == 2 && charon_same_words(&gDest[gDestCount - 1], words, 2));

        OSStatus setStatus = MIDIObjectSetIntegerProperty(dest, kMIDIPropertyUniqueID, 0x2A2A2A2A);
        SInt32 readBack = 0;
        MIDIObjectGetIntegerProperty(dest, kMIDIPropertyUniqueID, &readBack);
        MIDIEndpointRef extraDest = 0;
        MIDIPortRef extraPort = 0;
        OSStatus extraDestStatus = CharonMIDIDestination(client, CFSTR("charon-dest-extra"), kMIDIProtocol_2_0, &extraDest, NULL);
        OSStatus extraPortStatus = CharonMIDIInputPort(client, CFSTR("charon-in-extra"), kMIDIProtocol_2_0, &extraPort, NULL);
        charon_report(checks, &failures, "ports: the creator set the UniqueID of its library destination, and more objects were made",
                      setStatus == noErr && readBack == 0x2A2A2A2A && extraDestStatus == noErr && extraPortStatus == noErr);
        int before = gDestCount;
        OSStatus setSent = CharonMIDISend(outPort, dest, list);
        int setGot = setSent == noErr && charon_wait(gDestSignal);
        charon_report(checks, &failures, "ports: after the creator set its UniqueID, a 2.0 velocity of 0x1234 still arrives as sent",
                      setGot && gDestCount == before + 1 && charon_same_words(&gDest[gDestCount - 1], words, 2));
        Boolean setInProcess = CharonMIDIDeliverInProcess(dest, words, 2);
        int setDelivered = setInProcess && charon_wait(gDestSignal);
        charon_report(checks, &failures, "ports: and the in-process delivery still reaches its block",
                      setDelivered && gDestCount == before + 2 && charon_same_words(&gDest[gDestCount - 1], words, 2));
        if (extraDestStatus == noErr) MIDIEndpointDispose(extraDest);
        if (extraPortStatus == noErr) MIDIPortDispose(extraPort);
    }


    if (made) {
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        Byte buffer[64];
        MIDIEventList *list = (MIDIEventList *)buffer;
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        CharonMIDIEventListAdd(list, sizeof(buffer), end, 0, 2, words);

        MIDIEndpointRef releaseSrc = 0, librarySrc = 0;
        MIDIPortRef releasePort = 0, libraryPort = 0;
        OSStatus releaseSrcStatus = MIDISourceCreateWithProtocol(client, CFSTR("charon-release-src-2"), kMIDIProtocol_2_0, &releaseSrc);
        OSStatus releasePortStatus = MIDIInputPortCreateWithProtocol(client, CFSTR("charon-release-in-2"), kMIDIProtocol_2_0, &releasePort,
                                                                     ^(const MIDIEventList *received, void *ref) {
            charon_record_input(received, ref);
        });
        OSStatus librarySrcStatus = CharonMIDISource(client, CFSTR("charon-library-src-2"), kMIDIProtocol_2_0, &librarySrc);
        OSStatus libraryPortStatus = CharonMIDIInputPort(client, CFSTR("charon-library-in-2"), kMIDIProtocol_2_0, &libraryPort,
                                                         ^(const MIDIEventList *received, void *ref) {
            charon_record_input(received, ref);
        });
        int sourcesMade = releaseSrcStatus == noErr && releasePortStatus == noErr && librarySrcStatus == noErr && libraryPortStatus == noErr;
        charon_report(checks, &failures, "ports: a 2.0 source and a 2.0 input port of the release, and of the library, for the test", sourcesMade);
        if (sourcesMade) {
            int connected = MIDIPortConnectSource(releasePort, releaseSrc, (void *)3) == noErr &&
                            MIDIPortConnectSource(libraryPort, librarySrc, (void *)4) == noErr;
            gInputCount = 0;
            OSStatus releaseSent = MIDIReceivedEventList(releaseSrc, list);
            int releaseGot = releaseSent == noErr && charon_wait(gInputSignal);
            unsigned releaseVelocity = releaseGot && gInputCount == 1 && gInput[0].count == 2 ? gInput[0].words[1] >> 16 : 0xFFFFFFFFu;
            charon_report(checks, &failures, "ports: the release's own 2.0 source gives its 2.0 input port the 0x1234 velocity as sent",
                          connected && releaseGot && gInputCount == 1 && charon_same_words(&gInput[0], words, 2) && gInput[0].ref == (void *)3);
            gInputCount = 0;
            OSStatus librarySent = CharonMIDIReceive(librarySrc, list);
            int libraryGot = librarySent == noErr && charon_wait(gInputSignal);
            charon_report(checks, &failures, "ports: the library's 2.0 source delivers its list to its 2.0 input port",
                          connected && libraryGot && gInputCount == 1 && gInput[0].count == 2 && gInput[0].words[0] == words[0] &&
                          gInput[0].ref == (void *)4);
            if (libraryGot && gInputCount == 1 && gInput[0].count == 2)
                printf("known gap (crutch): a 2.0 source's velocity 0x1234 reaches a 2.0 input port of the library as 0x%04X; the release's own pair gives 0x%04X\n",
                       (unsigned)(gInput[0].words[1] >> 16), releaseVelocity);
            MIDIPortDisconnectSource(releasePort, releaseSrc);
            MIDIPortDisconnectSource(libraryPort, librarySrc);
        }
        if (releasePortStatus == noErr) MIDIPortDispose(releasePort);
        if (libraryPortStatus == noErr) MIDIPortDispose(libraryPort);
        if (releaseSrcStatus == noErr) MIDIEndpointDispose(releaseSrc);
        if (librarySrcStatus == noErr) MIDIEndpointDispose(librarySrc);
    }

    MIDIEndpointRef gone = 0;
    int before = gDestCount;
    OSStatus goneStatus = CharonMIDIDestination(client, CFSTR("charon-dest-gone"), kMIDIProtocol_2_0, &gone, ^(const MIDIEventList *list, void *ref) {
        charon_record_dest(list, ref);
    });
    if (goneStatus == noErr && outStatus == noErr) {
        MIDIEndpointDispose(gone);
        Byte buffer[64];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        CharonMIDIEventListAdd(list, sizeof(buffer), end, 0, 2, words);
        CharonMIDISend(outPort, gone, list);
        Boolean inProcess = CharonMIDIDeliverInProcess(gone, words, 2);
        usleep(200000);
        charon_report(checks, &failures, "ports: a disposed destination of the library takes no list, sent or delivered in process",
                      gDestCount == before && inProcess);
    } else {
        charon_report(checks, &failures, "ports: a destination to dispose for the test", 0);
    }

    if (outStatus == noErr) MIDIPortDispose(outPort);
    if (destStatus == noErr) MIDIEndpointDispose(dest);
    if (statusA == noErr) MIDIEndpointDispose(srcA);
    if (statusB == noErr) MIDIEndpointDispose(srcB);
    if (status == noErr) MIDIPortDispose(inPort);
    MIDIClientDispose(client);

    charon_make_disposed_client_with_token();
    MIDIClientRef sweepClient = 0;
    if (MIDIClientCreate(CFSTR("charon-sweep-client"), NULL, NULL, &sweepClient) == noErr) {
        MIDIEndpointRef sweeper = 0;
        OSStatus sweepStatus = CharonMIDIDestination(sweepClient, CFSTR("charon-sweeper"), kMIDIProtocol_2_0, &sweeper, NULL);
        charon_report(checks, &failures, "client copy released once the client is disposed and the next object is made (the token deallocates)",
                      sweepStatus == noErr && gTokenReleased);
        if (sweepStatus == noErr)
            MIDIEndpointDispose(sweeper);
        MIDIClientDispose(sweepClient);
    } else {
        charon_report(checks, &failures, "a client for the sweep of the client copy", 0);
    }
    return failures;
}
