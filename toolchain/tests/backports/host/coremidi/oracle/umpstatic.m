#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>

static MIDIUMPMutableFunctionBlock *block(NSString *name)
{
    return [[MIDIUMPMutableFunctionBlock alloc] initWithName:name direction:1 firstGroup:0 totalGroupsSpanned:1
                                             maxSysEx8Streams:0 MIDI1Info:0 UIHint:0 isEnabled:YES];
}

static void report(const char *label, MIDIUMPMutableEndpoint *ep)
{
    printf("%s: static %d, JRTS receive %d, JRTS transmit %d\n", label,
           (int)ep.hasStaticFunctionBlocks, (int)ep.hasJRTSReceiveCapability, (int)ep.hasJRTSTransmitCapability);
}

int main(void)
{
    @autoreleasepool {
        MIDI2DeviceManufacturer man = {{0x7e, 0x00, 0x00}}; MIDI2DeviceRevisionLevel rev = {{1, 2, 3, 4}};
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:man family:0x0102 modelNumber:0x0304
                                                                  revisionLevel:rev];
        MIDIUMPMutableEndpoint *ep = [[MIDIUMPMutableEndpoint alloc] initWithName:@"static-probe" deviceInfo:info
                                                                 productInstanceID:@"x" MIDIProtocol:kMIDIProtocol_2_0
                                                                 destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        if (!ep) {
            printf("endpoint: not created\n");
            return 1;
        }
        report("endpoint before any block", ep);
        BOOL notStatic = [ep registerFunctionBlocks:@[block(@"plain")] markAsStatic:NO error:NULL];
        report("after registerFunctionBlocks markAsStatic:NO", ep);
        printf("registerFunctionBlocks markAsStatic:NO answered %d\n", (int)notStatic);
        MIDIUMPMutableEndpoint *ep2 = [[MIDIUMPMutableEndpoint alloc] initWithName:@"static-probe-2" deviceInfo:info
                                                                  productInstanceID:@"y" MIDIProtocol:kMIDIProtocol_2_0
                                                                  destinationCallback:^(const MIDIEventList *list, void *ref) {}];
        BOOL isStatic = [ep2 registerFunctionBlocks:@[block(@"static")] markAsStatic:YES error:NULL];
        report("second endpoint after registerFunctionBlocks markAsStatic:YES", ep2);
        printf("registerFunctionBlocks markAsStatic:YES answered %d\n", (int)isStatic);
    }
    return 0;
}
