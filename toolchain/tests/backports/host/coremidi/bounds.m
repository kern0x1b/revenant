#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

#import "RevenantCoreMIDI.h"

static int gFailures;

static void expect(int passed, const char *what)
{
    printf("%s %s\n", passed ? "ok" : "FAIL", what);
    if (!passed)
        gFailures++;
}

static CFIndex gRequested = -1;

CFMutableDataRef revenant_test_CFDataCreateMutable(CFAllocatorRef allocator, CFIndex capacity)
{
    gRequested = capacity;
    if (capacity > (1 << 20))
        return NULL;
    return CFDataCreateMutable(allocator, capacity);
}

static OSStatus gClientStatus;
static int gClientCalls;
static NSMutableArray *gLog;

OSStatus revenant_test_MIDIClientCreate(CFStringRef name, MIDINotifyProc notifyProc, void *notifyRefCon, MIDIClientRef *outClient)
{
    gClientCalls++;
    if (gClientStatus == noErr)
        *outClient = 7;
    return gClientStatus;
}

OSStatus revenant_test_MIDIDestinationCreate(MIDIClientRef client, CFStringRef name, MIDIReadProc readProc, void *refCon,
                                           MIDIEndpointRef *outDest)
{
    *outDest = 8;
    return noErr;
}

OSStatus revenant_test_MIDISourceCreate(MIDIClientRef client, CFStringRef name, MIDIEndpointRef *outSrc)
{
    *outSrc = 9;
    return noErr;
}

OSStatus revenant_test_MIDIObjectSetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 value)
{
    return noErr;
}

OSStatus revenant_test_MIDIObjectGetIntegerProperty(MIDIObjectRef object, CFStringRef propertyID, SInt32 *outValue)
{
    return kMIDIUnknownProperty;
}

void revenant_test_NSLog(NSString *format, ...)
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
        MIDIEventPacket packet;
        memset(&packet, 0, sizeof(packet));
        packet.words[0] = 0x30060102u;
        packet.words[1] = 0x03040506u;
        packet.words[2] = 0x20903C40u;
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

        memset(&packet, 0, sizeof(packet));
        packet.words[0] = 0x30160102u;
        packet.words[1] = 0x03040506u;
        packet.words[2] = 0x30260708u;
        packet.words[3] = 0x090A0B0Cu;
        packet.words[4] = 0x30310D0Eu;
        packet.words[5] = 0x00000000u;
        packet.wordCount = 9;
        gRequested = -1;
        data = NULL;
        status = bytes_of(&packet, 0, &bytes, &length, &data);
        expect(status == noErr && gRequested == 24, "three parts ask for 24 bytes, and the trailing word asks for nothing");
        expect(data && length == 1 + 6 + 6 + 1 + 1, "and the message is F0, 13 data bytes and F7");
        if (data)
            CFRelease(data);

        gRequested = -1;
        status = bytes_of(&packet, 1, &bytes, &length, &data);
        expect(status == revenant_paramErr && gRequested == -1, "another group is paramErr, and nothing is asked for");

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
