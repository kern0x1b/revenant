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

static MIDIEndpointRef gNextDestination = 2;
static MIDIReadProc gDestProc;

OSStatus charon_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    gDestProc = readProc;
    *outDest = gNextDestination++;
    return noErr;
}

#define STANDIN_OBJECTS 4096
static SInt32 gOwnerValue[STANDIN_OBJECTS];
static int gOwnerSet[STANDIN_OBJECTS];
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
        OSStatus status = CharonMIDIInputPort(0, CFSTR("port"), kMIDIProtocol_2_0, &port, ^(const MIDIEventList *list, void *ref) {
            gDelivered += (int)list->numPackets;
        });
        if (status != noErr || !gReadProc) {
            printf("FAIL the library's input port was not registered with the release\n");
            return 1;
        }

        Byte buffer[256];
        MIDIPacketList *packets = (MIDIPacketList *)buffer;
        MIDIPacket *packet = MIDIPacketListInit(packets);
        packet = MIDIPacketListAdd(packets, sizeof(buffer), packet, 1, 3, (const Byte[]){0x90, 0x3C, 0x7F});
        packet = MIDIPacketListAdd(packets, sizeof(buffer), packet, 2, 3, (const Byte[]){0xB0, 0x07, 0x64});
        MIDIPacketListAdd(packets, sizeof(buffer), packet, 3, 2, (const Byte[]){0xD0, 0x50});
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

        static Byte big[4096];
        MIDIPacketList *bigList = (MIDIPacketList *)big;
        MIDIPacket *bigPacket = MIDIPacketListInit(bigList);
        for (int i = 0; i < 60; i++)
            bigPacket = MIDIPacketListAdd(bigList, sizeof(big), bigPacket, (MIDITimeStamp)(i + 1), 3, (const Byte[]){0x90, (Byte)i, 0x7F});
        gDelivered = 0;
        gMallocs = 0;
        gReadProc(bigList, gReadRefCon, (void *)1);
        expect(gDelivered == 60 && gMallocs > 0, "a list of sixty packets is converted whole (it needs the heap)", gMallocs);

        Byte listBuffer[64];
        MIDIEventList *list = (MIDIEventList *)listBuffer;
        MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
        UInt32 words[2] = {0x40903C00u, 0x12340000u};
        CharonMIDIEventListAdd(list, sizeof(listBuffer), end, 0, 2, words);
        gMallocs = 0;
        gReads = 0;
        gSent = 0;
        OSStatus sent = CharonMIDISend(0, 99, list);
        long firstSend = gMallocs;
        expect(sent == noErr && gSent == 1 && firstSend == 2, "the first send to a release endpoint makes its route and the table's first growth", firstSend);
        gMallocs = 0;
        gReads = 0;
        gSent = 0;
        sent = CharonMIDISend(0, 99, list);
        long send = gMallocs;
        expect(sent == noErr && gSent == 1 && send == 0 && gReads == 0,
               "a short 2.0 list sent to a release endpoint is converted without an allocation and without a property read", send);

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

        gLog = [NSMutableArray array];
        gFailAllocations = 1;
        for (int i = 0; i < 3; i++)
            gReadProc(bigList, gReadRefCon, (void *)1);
        NSUInteger afterFirst = gLog.count;
        for (int i = 0; i < 5; i++)
            gReadProc(packets, gReadRefCon, (void *)(uintptr_t)(10 + i));
        NSUInteger afterSecond = gLog.count;
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
