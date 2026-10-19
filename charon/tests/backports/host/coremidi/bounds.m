// Two residuals of the size and status classes, each against stand-ins for the release calls it makes:
//
// 1. MIDIEventPacketSysexBytesForGroup asked for room from the count the packet CLAIMS (wordCount / 2 * 8 bytes, a signed
//    overflow of a CFIndex on armv7 from wordCount 2^29, and a request of gigabytes on a 64-bit host), not from the SysEx parts
//    it holds. The room is now counted from the parts. CFDataCreateMutable is a stand-in that keeps what was asked and refuses
//    more than a megabyte.
// 2. The UMP endpoint's MIDI client is made with MIDIClientCreate, whose status was dropped: the endpoint came out nil with no
//    message. The status is now used, written, and a refused client is asked for again by the next endpoint.
//
// run.sh renames the release's calls in MIDISysex17.m and MIDIUMP18.m (and the two files' classes, as it does for the
// differential) and links nothing from the release for them.
#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

#import "CharonCoreMIDI.h"

static int gFailures;

static void expect(int passed, const char *what)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", what);
    if (!passed)
        gFailures++;
}

static CFIndex gRequested = -1;

CFMutableDataRef charon_test_CFDataCreateMutable(CFAllocatorRef allocator, CFIndex capacity)
{
    gRequested = capacity;
    if (capacity > (1 << 20))
        return NULL;
    return CFDataCreateMutable(allocator, capacity);
}

static OSStatus gClientStatus;
static int gClientCalls;
static NSMutableArray *gLog;

OSStatus charon_test_MIDIClientCreate(CFStringRef name, MIDINotifyProc notifyProc, void *notifyRefCon, MIDIClientRef *outClient)
{
    gClientCalls++;
    if (gClientStatus == noErr)
        *outClient = 7;
    return gClientStatus;
}

OSStatus charon_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    *outDest = 8;
    return noErr;
}

OSStatus charon_test_MIDISourceCreate(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outSrc)
{
    *outSrc = 9;
    return noErr;
}

OSStatus charon_test_MIDIObjectSetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 value)
{
    return noErr;
}

OSStatus charon_test_MIDIObjectGetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 *outValue)
{
    return kMIDIUnknownProperty;
}

void charon_test_NSLog(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [gLog addObject:line];
}

static OSStatus bytes_of(const MIDIEventPacket *packet, UInt8 group, const UInt8 **out, CFIndex *length, CFDataRef *keep)
{
    *keep = NULL;
    OSStatus status = MIDIEventPacketSysexBytesForGroup(packet, group, keep);
    if (*keep) {
        *out = CFDataGetBytePtr(*keep);
        *length = CFDataGetLength(*keep);
    }
    return status;
}

int main(void)
{
    @autoreleasepool {
        // A packet that claims 2^31 words and holds one SysEx7 part (a complete message of six bytes) and then a word that is
        // not SysEx: nothing past the third word is read.
        MIDIEventPacket packet;
        memset(&packet, 0, sizeof(packet));
        packet.words[0] = 0x30060102u;  // type 3, group 0, status 0 (complete), 6 bytes: 01 02 ...
        packet.words[1] = 0x03040506u;
        packet.words[2] = 0x20903C40u;  // a MIDI 1.0 channel voice word: ends the SysEx parts
        packet.wordCount = 0x80000000u;
        const UInt8 *bytes = NULL;
        CFIndex length = 0;
        CFDataRef data = NULL;
        gRequested = -1;
        OSStatus status = bytes_of(&packet, 0, &bytes, &length, &data);
        expect(status == noErr && data != NULL, "a packet that claims 2^31 words and holds one part is read");
        expect(gRequested == 8, "and it asked for the room of the one part it holds (8 bytes), not of the words it claims");
        static const UInt8 expected[8] = {0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0xF7};
        expect(data && length == 8 && memcmp(bytes, expected, 8) == 0, "and the bytes are F0, the six data bytes and F7");
        if (data)
            CFRelease(data);

        // The words past the parts are not asked for either: three parts of a packet of nine words.
        memset(&packet, 0, sizeof(packet));
        packet.words[0] = 0x30160102u;  // start, 6 bytes
        packet.words[1] = 0x03040506u;
        packet.words[2] = 0x30260708u;  // continue, 6 bytes
        packet.words[3] = 0x090A0B0Cu;
        packet.words[4] = 0x30310D0Eu;  // end, 1 byte (n = 1)
        packet.words[5] = 0x00000000u;
        packet.wordCount = 9;
        gRequested = -1;
        data = NULL;
        status = bytes_of(&packet, 0, &bytes, &length, &data);
        expect(status == noErr && gRequested == 24, "three parts ask for 24 bytes, and the trailing word asks for nothing");
        expect(data && length == 1 + 6 + 6 + 1 + 1, "and the message is F0, 13 data bytes and F7");
        if (data)
            CFRelease(data);

        // A group that is not the packet's is paramErr with no data and no room asked for.
        gRequested = -1;
        status = bytes_of(&packet, 1, &bytes, &length, &data);
        expect(status == charon_paramErr && gRequested == -1, "another group is paramErr, and nothing is asked for");

        // The endpoint's client: the release refuses it.
        MIDI2DeviceManufacturer manufacturer = {{0x12, 0x34, 0x56}};
        MIDI2DeviceRevisionLevel revision = {{0x01, 0x02, 0x03, 0x04}};
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:manufacturer family:1 modelNumber:2 revisionLevel:revision];
        gLog = [NSMutableArray array];
        gClientStatus = -10844;
        gClientCalls = 0;
        MIDIUMPMutableEndpoint *refused = [[MIDIUMPMutableEndpoint alloc] initWithName:@"one" deviceInfo:info productInstanceID:@"p"
                                                                         MIDIProtocol:kMIDIProtocol_2_0
                                                                  destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        BOOL said = gLog.count == 1 && [gLog[0] containsString:@"-10844"];
        expect(refused == nil && gClientCalls == 1 && said, "a refused client makes no endpoint, and the status is written");
        MIDIUMPMutableEndpoint *again = [[MIDIUMPMutableEndpoint alloc] initWithName:@"two" deviceInfo:info productInstanceID:@"p"
                                                                       MIDIProtocol:kMIDIProtocol_2_0
                                                                destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        expect(again == nil && gClientCalls == 2 && gLog.count == 1, "the next endpoint asks again, and the same status is not written again");
        // The release answers now: the client is made once, and the endpoints are made over it.
        gClientStatus = noErr;
        MIDIUMPMutableEndpoint *made = [[MIDIUMPMutableEndpoint alloc] initWithName:@"three" deviceInfo:info productInstanceID:@"p"
                                                                      MIDIProtocol:kMIDIProtocol_2_0
                                                               destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        MIDIUMPMutableEndpoint *second = [[MIDIUMPMutableEndpoint alloc] initWithName:@"four" deviceInfo:info productInstanceID:@"p"
                                                                        MIDIProtocol:kMIDIProtocol_2_0
                                                                 destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        expect(made != nil && second != nil && gClientCalls == 3, "when the release answers the client is made once and the endpoints are made");
    }
    printf("bounds: %d failures\n", gFailures);
    return gFailures ? 1 : 0;
}
