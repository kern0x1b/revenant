// The heap allocations the library's hot paths make, counted: the library's own malloc, calloc and realloc calls (run.sh renames
// them in CharonMIDIPorts.m and CharonCoreMIDI.c to the counting wrappers below), per operation, and the calls it makes to the
// release's property read. On a 4S (A5, 512 MB) every allocation on the read thread of the release or on an audio thread is
// a cost the release's own paths do not have: a short list is converted in stack storage, and only a list too big for it is
// allocated. The release's calls are stand-ins (no MIDI object is made): the port's read procedure is the one the library hands
// to MIDIInputPortCreate, called here with a packet list as the release would. Calls the frameworks make inside themselves (the
// copy of a block, the queue's continuation) are not the library's own calls and are not counted. Each line prints the counts;
// the same file is run against an earlier library (COREMIDI=<its folder>) for the "before" counts.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#import "CharonCoreMIDI.h"

static int gFailures;
static long gMallocs;
static long gReads;
static int gFailAllocations;

void *charon_count_malloc(size_t size)
{
    gMallocs++;
    return gFailAllocations ? NULL : malloc(size);
}

void *charon_count_calloc(size_t count, size_t size)
{
    gMallocs++;
    return gFailAllocations ? NULL : calloc(count, size);
}

void *charon_count_realloc(void *pointer, size_t size)
{
    gMallocs++;
    return gFailAllocations ? NULL : realloc(pointer, size);
}

// The log: NSLog in CharonMIDIPorts.m is renamed to this (run.sh), which keeps what was written.
static NSMutableArray *gLog;

void charon_test_NSLog(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [gLog addObject:line];
}

static MIDIReadProc gReadProc;
static void *gReadRefCon;
static int gDelivered;
static dispatch_semaphore_t gDeliveredSignal;

OSStatus charon_test_MIDIInputPortCreate(MIDIClientRef client, CFStringRef portName, MIDIReadProc readProc, void *refCon,
                                         MIDIPortRef *outPort)
{
    gReadProc = readProc;
    gReadRefCon = refCon;
    *outPort = 1;
    return noErr;
}

// The references the stand-in gives to destinations: each one is new (the owned table is keyed by the reference).
static MIDIEndpointRef gNextDestination = 2;
static MIDIReadProc gDestProc;

OSStatus charon_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    gDestProc = readProc;
    *outDest = gNextDestination++;
    return noErr;
}

// The properties the stand-in object holds: any key reads back what was written; an unwritten key is unknown. The table holds the
// references of the test's own destinations (up to 1024 of them, from 1000 on).
#define STANDIN_OBJECTS 4096
static SInt32 gOwnerValue[STANDIN_OBJECTS];
static int gOwnerSet[STANDIN_OBJECTS];
// The thread that makes the sends: the reads it makes are the ones a send makes (the test counts them apart).
static pthread_t gSender;
static long gSenderReads;

OSStatus charon_test_MIDIObjectSetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 value)
{
    if (object < STANDIN_OBJECTS && propertyID && CFEqual(propertyID, CHARON_OWNER_KEY)) {
        gOwnerValue[object] = value;
        gOwnerSet[object] = 1;
    }
    return noErr;
}

OSStatus charon_test_MIDIObjectGetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 *outValue)
{
    gReads++;
    if (pthread_equal(pthread_self(), gSender))
        gSenderReads++;
    if (object < STANDIN_OBJECTS && propertyID && CFEqual(propertyID, CHARON_OWNER_KEY) && gOwnerSet[object]) {
        *outValue = gOwnerValue[object];
        return noErr;
    }
    return kMIDIUnknownProperty;
}

static int gSent;

OSStatus charon_test_MIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIPacketList *pktlist)
{
    gSent += (int)pktlist->numPackets;
    return noErr;
}

OSStatus charon_test_MIDIReceived(MIDIEndpointRef src, const MIDIPacketList *pktlist)
{
    gSent += (int)pktlist->numPackets;
    return noErr;
}

// The release's sysex send, as a stand-in (run.sh renames the library's MIDISendSysex to it): it copies the bytes it is given, then
// completes the send before it returns, as the release may. The completion frees the library's block during the call, so the
// stand-in touches the request only before the completion.
static int gSysexCalls;
static size_t gSysexCopied;
static UInt8 gSysexCopy[16];

OSStatus charon_test_MIDISendSysex(MIDISysexSendRequest *request)
{
    gSysexCalls++;
    gSysexCopied = request->bytesToSend < sizeof(gSysexCopy) ? request->bytesToSend : sizeof(gSysexCopy);
    memcpy(gSysexCopy, request->data, gSysexCopied);
    request->completionProc(request);
    return noErr;
}

static void expect(int passed, const char *what, long allocations)
{
    printf("%s %s (%ld allocation(s), %ld property read(s))\n", passed ? "ok" : "FAIL", what, allocations, gReads);
    if (!passed)
        gFailures++;
}

static void expect_lines(int passed, const char *what, long lines)
{
    printf("%s %s (%ld log line(s) so far)\n", passed ? "ok" : "FAIL", what, lines);
    if (!passed)
        gFailures++;
}

int main(void)
{
    @autoreleasepool {
        gDeliveredSignal = dispatch_semaphore_create(0);
        gSender = pthread_self();
        MIDIPortRef port = 0;
        // A 2.0 input port with a block: the library's read procedure is registered with the release (the stand-in).
        OSStatus status = CharonMIDIInputPort(0, CFSTR("port"), kMIDIProtocol_2_0, &port, ^(const MIDIEventList *list, void *ref) {
            gDelivered += (int)list->numPackets;
        });
        if (status != noErr || !gReadProc) {
            printf("FAIL the library's input port was not registered with the release\n");
            return 1;
        }

        // The read callback of a list of three MIDI 1.0 packets: a note on, a controller, a channel pressure.
        Byte buffer[256];
        MIDIPacketList *packets = (MIDIPacketList *)buffer;
        MIDIPacket *packet = MIDIPacketListInit(packets);
        packet = MIDIPacketListAdd(packets, sizeof(buffer), packet, 1, 3, (const Byte[]){0x90, 0x3C, 0x7F});
        packet = MIDIPacketListAdd(packets, sizeof(buffer), packet, 2, 3, (const Byte[]){0xB0, 0x07, 0x64});
        MIDIPacketListAdd(packets, sizeof(buffer), packet, 3, 2, (const Byte[]){0xD0, 0x50});
        // The first list of a source makes the source's parser (the port's table of sources may grow: one allocation); the
        // lists after it make none.
        gMallocs = 0;
        gDelivered = 0;
        gReadProc(packets, gReadRefCon, (void *)1);
        long firstRead = gMallocs;
        expect(gDelivered == 3 && firstRead <= 1, "the first list of a source makes its parser", firstRead);
        gMallocs = 0;
        gReads = 0;
        gDelivered = 0;
        gReadProc(packets, gReadRefCon, (void *)1);
        long read = gMallocs;
        expect(gDelivered == 3 && read == 0 && gReads == 0,
               "a read callback of three short packets is converted without an allocation and without a property read", read);

        // A list too long for the stack storage still works, and allocates (the list, and the words past the stack words).
        static Byte big[4096];
        MIDIPacketList *bigList = (MIDIPacketList *)big;
        MIDIPacket *bigPacket = MIDIPacketListInit(bigList);
        for (int i = 0; i < 60; i++)
            bigPacket = MIDIPacketListAdd(bigList, sizeof(big), bigPacket, (MIDITimeStamp)(i + 1), 3, (const Byte[]){0x90, (Byte)i, 0x7F});
        gDelivered = 0;
        gMallocs = 0;
        gReadProc(bigList, gReadRefCon, (void *)1);
        expect(gDelivered == 60 && gMallocs > 0, "a list of sixty packets is converted whole (it needs the heap)", gMallocs);

        // A send of a short 2.0 list to an endpoint that is not this library's: converted to bytes in stack storage.
        Byte listBuffer[64];
        MIDIEventList *list = (MIDIEventList *)listBuffer;
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        CharonMIDIEventListAdd(list, sizeof(listBuffer), end, 0, 2, words);
        // The first send to an endpoint makes the endpoint's selection state (the table may grow: one allocation), and the
        // sends after it make none.
        gMallocs = 0;
        gReads = 0;
        gSent = 0;
        OSStatus sent = CharonMIDISend(0, 99, list);
        long firstSend = gMallocs;
        // The count of two is a design bound, not a measurement: the endpoint's route is one object (one allocation), and the table
        // of routes grows from nothing at the first route (another). The bound is pinned because a third allocation on the first send
        // is a change of the design that the test has to show. It is not an oracle: no measurement against Apple gives this count (the
        // release's own allocations are not visible to the test). A second endpoint makes its route alone (checked below).
        expect(sent == noErr && gSent == 1 && firstSend == 2, "the first send to a release endpoint makes its route and the table's first growth", firstSend);
        gMallocs = 0;
        gReads = 0;
        gSent = 0;
        sent = CharonMIDISend(0, 99, list);
        long send = gMallocs;
        expect(sent == noErr && gSent == 1 && send == 0 && gReads == 0,
               "a short 2.0 list sent to a release endpoint is converted without an allocation and without a property read", send);

        // The same list to a destination this library made: delivered verbatim on the queue, one allocation for the delivery.
        MIDIEndpointRef dest = 0;
        OSStatus destStatus = CharonMIDIDestination(0, CFSTR("dest"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *received, void *ref) {
            gDelivered = (int)received->numPackets;
            dispatch_semaphore_signal(gDeliveredSignal);
        });
        gMallocs = 0;
        gReads = 0;
        gDelivered = 0;
        gSenderReads = 0;
        OSStatus inProcess = destStatus == noErr ? CharonMIDISend(0, dest, list) : destStatus;
        long delivery = gMallocs;
        long senderReads = gSenderReads;
        int arrived = dispatch_semaphore_wait(gDeliveredSignal, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        expect(inProcess == noErr && arrived && gDelivered == 1 && delivery == 1 && senderReads == 0,
               "a list sent to the library's own destination is delivered with one allocation, and its send reads no property", delivery);

        // A process with 1024 destinations of its own: the owned table is searched by reference, so a send reaches the first and the
        // last of them alike, each with one allocation (its delivery) and no property read on the sender's thread.
        gNextDestination = 1000;
        static MIDIEndpointRef rows[1024];
        int made = 1;
        for (int i = 0; i < 1024 && made; i++)
            made = CharonMIDIDestination(0, CFSTR("row"), kMIDIProtocol_2_0, &rows[i], ^(const MIDIEventList *received, void *ref) {
                dispatch_semaphore_signal(gDeliveredSignal);
            }) == noErr;
        long rowAllocations = 0;
        long rowReads = 0;
        int reached = made;
        MIDIEndpointRef ends[2] = {rows[0], rows[1023]};
        for (int k = 0; k < 2 && reached; k++) {
            gMallocs = 0;
            gSenderReads = 0;
            OSStatus rowStatus = CharonMIDISend(0, ends[k], list);
            rowAllocations += gMallocs;
            rowReads += gSenderReads;
            reached = rowStatus == noErr && dispatch_semaphore_wait(gDeliveredSignal, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)) == 0;
        }
        expect(reached && rowAllocations == 2 && rowReads == 0,
               "a send to the first and the last of 1024 destinations is delivered, one allocation each, with no read on the sender's thread",
               rowAllocations);
        // A second release endpoint makes its route alone; a send through an existing route allocates nothing and reads nothing.
        gMallocs = 0;
        gSent = 0;
        OSStatus second = CharonMIDISend(0, 100, list);
        long secondEndpoint = gMallocs;
        expect(second == noErr && gSent == 1 && secondEndpoint == 1, "a second release endpoint makes its route alone", secondEndpoint);
        gMallocs = 0;
        gReads = 0;
        gSent = 0;
        second = CharonMIDISend(0, 100, list);
        expect(second == noErr && gSent == 1 && gMallocs == 0 && gReads == 0, "a send through an existing route allocates nothing and reads nothing",
               gMallocs);

        // A UMP SysEx of three data bytes sent to a release endpoint: the words are converted in stack storage, and the bytes are copied
        // once into the block that the release's send keeps until it completes (the stand-in completes it before returning). One
        // allocation, the block; the bytes are the MIDI 1.0 framing of the data (F0, the data, F7).
        UInt32 sysex[2] = {0x30030102u, 0x03000000u};
        MIDISysexSendRequestUMP umpRequest;
        memset(&umpRequest, 0, sizeof(umpRequest));
        gMallocs = 0;
        gSysexCalls = 0;
        int queuedSysex = CharonMIDIUMPReleaseSend(&umpRequest, 99, sysex, 2);
        long sysexAllocations = gMallocs;
        static const UInt8 framed[5] = {0xF0, 0x01, 0x02, 0x03, 0xF7};
        int framedRight = gSysexCopied == sizeof(framed) && memcmp(gSysexCopy, framed, sizeof(framed)) == 0;
        expect(queuedSysex == 1 && gSysexCalls == 1 && framedRight && umpRequest.complete == YES && sysexAllocations == 1,
               "a UMP sysex of three bytes to a release endpoint is sent as its MIDI 1.0 bytes, with one allocation (the block its completion frees)",
               sysexAllocations);

        // A refusal is written once for its reason, and one reason's refusal does not hide another's: the allocator is made to
        // fail, and the same refusal is made three times for each of three reasons. The table of reasons is two here
        // (CHARON_REFUSED_REASONS, renamed in the build), so the third is the one that finds it full.
        gLog = [NSMutableArray array];
        gFailAllocations = 1;
        for (int i = 0; i < 3; i++)
            gReadProc(bigList, gReadRefCon, (void *)1); // a list that needs the heap: "a list the allocator would not give"
        NSUInteger afterFirst = gLog.count;
        for (int i = 0; i < 5; i++)
            gReadProc(packets, gReadRefCon, (void *)(uintptr_t)(10 + i)); // the fifth source of the port does not fit its table: "a source whose parser cannot be made"
        NSUInteger afterSecond = gLog.count;
        // More than the 32 words of the stack storage in one packet: "the words of a packet, which could not be allocated".
        static Byte many[512];
        MIDIPacketList *manyList = (MIDIPacketList *)many;
        MIDIPacket *manyPacket = MIDIPacketListInit(manyList);
        Byte notes[60];
        for (int i = 0; i < 20; i++) {
            notes[3 * i] = 0x90;
            notes[3 * i + 1] = (Byte)i;
            notes[3 * i + 2] = 0x7F;
        }
        MIDIPacketListAdd(manyList, sizeof(many), manyPacket, 1, sizeof(notes), notes);
        for (int i = 0; i < 3; i++)
            gReadProc(manyList, gReadRefCon, (void *)1);
        gFailAllocations = 0;
        BOOL firstOnce = afterFirst == 1 && [gLog[0] containsString:@"a list the allocator would not give"];
        BOOL secondAnother = afterSecond == 2 && [gLog[1] containsString:@"a source whose parser cannot be made"];
        BOOL thirdFull = gLog.count == 3 && [gLog[2] containsString:@"more than 2 different things"];
        expect_lines(firstOnce, "a refusal is written once, and not again when it is made again", (long)afterFirst);
        expect_lines(secondAnother, "a refusal of another reason is written after it (one reason does not hide another)", (long)afterSecond);
        expect_lines(thirdFull, "a reason that does not fit the bounded table says so once, and nothing is written after", (long)gLog.count);
        gLog = nil;
    }
    printf("allocations: %d failures\n", gFailures);

    return gFailures ? 1 : 0;
}
