#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

#import "CharonCoreMIDI.h"

static int gFailures;

static MIDIEndpointRef gNextDestination = 2;

OSStatus charon_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    *outDest = gNextDestination;
    return noErr;
}

#define REFERENCES 64
static SInt32 gOwnerValue[REFERENCES];
static int gOwnerSet[REFERENCES];

OSStatus charon_test_MIDIObjectSetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 value)
{
    if (object < REFERENCES && propertyID && CFEqual(propertyID, CHARON_OWNER_KEY)) {
        gOwnerValue[object] = value;
        gOwnerSet[object] = 1;
    }
    return noErr;
}

OSStatus charon_test_MIDIObjectGetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 *outValue)
{
    if (object < REFERENCES && propertyID && CFEqual(propertyID, CHARON_OWNER_KEY) && gOwnerSet[object]) {
        *outValue = gOwnerValue[object];
        return noErr;
    }
    return kMIDIUnknownProperty;
}

static MIDIEndpointRef gNextSource = 2;

OSStatus charon_test_MIDISourceCreate(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outSrc)
{
    *outSrc = gNextSource;
    return noErr;
}

static unsigned char gBytes[256];
static size_t gByteCount;
static MIDIEndpointRef gSentTo;

static void record_packets(MIDIEndpointRef endpoint, const MIDIPacketList *pktlist)
{
    gSentTo = endpoint;
    const MIDIPacket *packet = &pktlist->packet[0];
    for (UInt32 i = 0; i < pktlist->numPackets; i++) {
        for (UInt16 k = 0; k < packet->length && gByteCount < sizeof(gBytes); k++)
            gBytes[gByteCount++] = packet->data[k];
        packet = MIDIPacketNext(packet);
    }
}

OSStatus charon_test_MIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIPacketList *pktlist)
{
    record_packets(dest, pktlist);
    return noErr;
}

OSStatus charon_test_MIDIReceived(MIDIEndpointRef src, const MIDIPacketList *pktlist)
{
    record_packets(src, pktlist);
    return noErr;
}

static MIDIEventList *rpn_list(uint8_t *storage, size_t size, UInt32 value)
{
    MIDIEventList *list = (MIDIEventList *)storage;
    MIDIEventPacket *end = MIDIEventListInit(list, kMIDIProtocol_2_0);
    UInt32 words[2] = {0x40200000u, value};
    CharonMIDIEventListAdd(list, size, end, 0, 2, words);
    return list;
}

static OSStatus send_rpn(MIDIEndpointRef dest, UInt32 value)
{
    uint8_t storage[64] __attribute__((aligned(8)));
    gByteCount = 0;
    gSentTo = 0;
    return CharonMIDISend((MIDIPortRef)1, dest, rpn_list(storage, sizeof(storage), value));
}

static OSStatus receive_rpn(MIDIEndpointRef src, UInt32 value)
{
    uint8_t storage[64] __attribute__((aligned(8)));
    gByteCount = 0;
    gSentTo = 0;
    return CharonMIDIReceive(src, rpn_list(storage, sizeof(storage), value));
}

static void expect_bytes(const unsigned char *expected, size_t count, MIDIEndpointRef dest, const char *what)
{
    int passed = gSentTo == dest && gByteCount == count && memcmp(gBytes, expected, count) == 0;
    printf("%s %s: sent to %u, bytes", passed ? "ok  " : "FAIL", what, (unsigned int)gSentTo);
    for (size_t i = 0; i < gByteCount; i++)
        printf(" %02X", gBytes[i]);
    printf("\n");
    if (!passed)
        gFailures++;
}

static void expect(int passed, const char *what)
{
    printf("%s %s\n", passed ? "ok  " : "FAIL", what);
    if (!passed)
        gFailures++;
}

static const unsigned char kSelectAndData1[] = {0xB0, 0x65, 0x00, 0xB0, 0x64, 0x00, 0xB0, 0x06, 0x01};
static const unsigned char kDataOnly2[] = {0xB0, 0x06, 0x02};
static const unsigned char kSelectAndData3[] = {0xB0, 0x65, 0x00, 0xB0, 0x64, 0x00, 0xB0, 0x06, 0x03};

static MIDIReceiveBlock noBlock = ^(const MIDIEventList *list, void *refCon) {
};

int main(void)
{
    @autoreleasepool {
        MIDIEndpointRef first = 0;
        gNextDestination = 5;
        expect(CharonMIDIDestination(0, CFSTR("first"), kMIDIProtocol_1_0, &first, noBlock) == noErr && first == 5,
               "the library makes a 1.0 destination at reference 5");
        expect(send_rpn(5, 1u << 25) == noErr, "the first RPN is sent to the destination");
        expect_bytes(kSelectAndData1, sizeof(kSelectAndData1), 5,
                     "the first RPN of a destination selects its parameter, then sends its data (macOS, probe2 line 4)");
        expect(send_rpn(5, 2u << 25) == noErr, "the same parameter is sent again to the same destination");
        expect_bytes(kDataOnly2, sizeof(kDataOnly2), 5,
                     "the same parameter again on the same destination sends its data alone (macOS, probe2 line 7)");
        MIDIEndpointRef second = 0;
        gNextDestination = 5;
        expect(CharonMIDIDestination(0, CFSTR("second"), kMIDIProtocol_1_0, &second, noBlock) == noErr && second == 5,
               "the release gives reference 5 to a new destination, which the library makes");
        expect(send_rpn(5, 3u << 25) == noErr, "the first RPN is sent to the new destination");
        expect_bytes(kSelectAndData3, sizeof(kSelectAndData3), 5,
                     "the new destination's first RPN selects its parameter: the old route's selection is not inherited");
        MIDIEndpointRef firstSource = 0;
        gNextSource = 7;
        expect(CharonMIDISource(0, CFSTR("first-source"), kMIDIProtocol_2_0, &firstSource) == noErr && firstSource == 7,
               "the library makes a 2.0 source at reference 7");
        expect(receive_rpn(7, 1u << 25) == noErr, "the first RPN is received from the source");
        expect_bytes(kSelectAndData1, sizeof(kSelectAndData1), 7,
                     "the first RPN a source receives selects its parameter (the destination's answer, probe2 line 4)");
        expect(receive_rpn(7, 2u << 25) == noErr, "the same parameter is received again from the same source");
        expect_bytes(kDataOnly2, sizeof(kDataOnly2), 7, "the same parameter again from the same source sends its data alone (the destination's answer, probe2 line 7)");
        MIDIEndpointRef secondSource = 0;
        gNextSource = 7;
        expect(CharonMIDISource(0, CFSTR("second-source"), kMIDIProtocol_2_0, &secondSource) == noErr && secondSource == 7,
               "the release gives reference 7 to a new source, which the library makes");
        expect(receive_rpn(7, 3u << 25) == noErr, "the first RPN is received from the new source");
        expect_bytes(kSelectAndData3, sizeof(kSelectAndData3), 7,
                     "the new source's first RPN selects its parameter: the old source's selection is not inherited");
    }
    printf("%s\n", gFailures ? "reuse: FAIL" : "reuse: ok");
    return gFailures ? 1 : 0;
}
