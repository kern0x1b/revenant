#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <unistd.h>

static volatile int gCalls;

static MIDIUMPMutableFunctionBlock *block(NSString *name, MIDIUMPFunctionBlockDirection direction, MIDIUMPGroupNumber first)
{
    return [[MIDIUMPMutableFunctionBlock alloc] initWithName:name direction:direction firstGroup:first totalGroupsSpanned:1
                                             maxSysEx8Streams:0 MIDI1Info:0 UIHint:0 isEnabled:YES];
}

static void send(MIDIPortRef port, MIDIEndpointRef destination)
{
    Byte buffer[64];
    MIDIEventList *list = (MIDIEventList *)buffer;
    UInt32 words[2] = {0x40903C00u, 0xFFFF0000u};
    MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof(buffer), packet, 0, 2, words);
    MIDISendEventList(port, destination, list);
}

int main(void)
{
    @autoreleasepool {
        MIDI2DeviceManufacturer man = {{0x7e, 0x00, 0x00}};
        MIDI2DeviceRevisionLevel rev = {{1, 2, 3, 4}};
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:man family:0x0102 modelNumber:0x0304 revisionLevel:rev];
        MIDIUMPMutableEndpoint *ep = [[MIDIUMPMutableEndpoint alloc] initWithName:@"gate-probe" deviceInfo:info
                                                                 productInstanceID:@"g" MIDIProtocol:kMIDIProtocol_2_0
                                                                 destinationCallback:^(const MIDIEventList *list, void *ref) { gCalls++; }];
        MIDIPortRef port = 0;
        MIDIOutputPortCreate(MIDIClientCreate(CFSTR("gate-client"), NULL, NULL, &(MIDIClientRef){0}) == noErr ? 0 : 0, CFSTR("p"), &port);
        MIDIClientRef client = 0;
        MIDIClientCreate(CFSTR("gate-client-2"), NULL, NULL, &client);
        MIDIOutputPortCreate(client, CFSTR("gate-out"), &port);
        printf("endpoint enabled before setEnabled: %d\n", (int)ep.isEnabled);
        gCalls = 0;
        send(port, ep.MIDIDestination);
        usleep(300000);
        printf("send while disabled (never enabled): callback calls %d\n", gCalls);
        [ep setEnabled:YES error:NULL];
        gCalls = 0;
        send(port, ep.MIDIDestination);
        usleep(300000);
        printf("send while enabled: callback calls %d\n", gCalls);
        [ep setEnabled:NO error:NULL];
        gCalls = 0;
        send(port, ep.MIDIDestination);
        usleep(300000);
        printf("send after setEnabled:NO: callback calls %d\n", gCalls);
        [ep setEnabled:YES error:NULL];
        NSArray *blocks = @[block(@"first", 1, 0), block(@"second", 2, 4), block(@"third", 1, 8)];
        [ep registerFunctionBlocks:blocks markAsStatic:NO error:NULL];
        NSMutableString *ids = [NSMutableString string];
        for (MIDIUMPFunctionBlock *b in ep.functionBlocks)
            [ids appendFormat:@"%u ", (unsigned)b.functionBlockID];
        printf("function block IDs of three blocks (registration order): %s\n", [ids UTF8String]);
    }
    return 0;
}
