#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
static MIDIUMPMutableFunctionBlock *block(NSString *name, MIDIUMPFunctionBlockDirection d, MIDIUMPGroupNumber first, MIDIUInteger7 total, UInt8 streams, BOOL enabled) {
    return [[MIDIUMPMutableFunctionBlock alloc] initWithName:name direction:d firstGroup:first totalGroupsSpanned:total maxSysEx8Streams:streams MIDI1Info:0 UIHint:0 isEnabled:enabled];
}
int main(void) {
    @autoreleasepool {
        printf("fb groups 0+17: %s\n", block(@"a", 1, 0, 17, 0, YES) ? "yes" : "nil");
        printf("fb groups 15+2: %s\n", block(@"a", 1, 15, 2, 0, YES) ? "yes" : "nil");
        printf("fb groups total 0: %s\n", block(@"a", 1, 0, 0, 0, YES) ? "yes" : "nil");
        printf("fb direction 0: %s\n", block(@"a", 0, 0, 1, 0, YES) ? "yes" : "nil");
        printf("fb direction 7: %s\n", block(@"a", 7, 0, 1, 0, YES) ? "yes" : "nil");
        printf("fb streams 4: %s\n", block(@"a", 1, 0, 1, 4, YES) ? "yes" : "nil");
        printf("fb streams 5: %s\n", block(@"a", 1, 0, 1, 5, YES) ? "yes" : "nil");
        MIDIUMPMutableFunctionBlock *fb = block(@"a", 1, 2, 3, 0, NO);
        printf("fb disabled: enabled=%d first=%u groups=%u dir=%d\n", (int)fb.isEnabled, (unsigned)fb.firstGroup, (unsigned)fb.totalGroupsSpanned, (int)fb.direction);
        printf("fb setEnabled YES: %d\n", (int)[fb setEnabled:YES error:NULL]);
        printf("fb setName: %d name=%s\n", (int)[fb setName:@"renamed" error:NULL], [fb.name UTF8String]);
        printf("fb reconfigure: %d first=%u dir=%d\n", (int)[fb reconfigureWithFirstGroup:4 direction:2 MIDI1Info:1 UIHint:2 error:NULL], (unsigned)fb.firstGroup, (int)fb.direction);
        printf("fb reconfigure 15+4: %d\n", (int)[fb reconfigureWithFirstGroup:15 direction:2 MIDI1Info:1 UIHint:2 error:NULL]);
        MIDI2DeviceManufacturer man = {{0x7e, 0x00, 0x00}}; MIDI2DeviceRevisionLevel rev = {{1, 2, 3, 4}};
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:man family:0x0102 modelNumber:0x0304 revisionLevel:rev];
        MIDIUMPMutableEndpoint *ep = [[MIDIUMPMutableEndpoint alloc] initWithName:@"e2" deviceInfo:info productInstanceID:@"x" MIDIProtocol:kMIDIProtocol_1_0 destinationCallback:^(const MIDIEventList *l, void *r) {}];
        printf("endpoint protocol 1.0 created: %s\n", ep ? "yes" : "nil");
        printf("UMPEndpoints before enabling: %lu\n", (unsigned long)[MIDIUMPEndpointManager.sharedInstance UMPEndpoints].count);
        printf("ep setName: %d\n", (int)[ep setName:@"renamed" error:NULL]);
        printf("ep name=%s enabled=%d protocol=%d\n", [ep.name UTF8String], (int)ep.isEnabled, (int)ep.MIDIProtocol);
        printf("ep setEnabled YES: %d enabled=%d\n", (int)[ep setEnabled:YES error:NULL], (int)ep.isEnabled);
        printf("UMPEndpoints after enabling: %lu\n", (unsigned long)[MIDIUMPEndpointManager.sharedInstance UMPEndpoints].count);
        printf("ep registerFunctionBlocks (1): %d\n", (int)[ep registerFunctionBlocks:@[block(@"f", 1, 0, 1, 0, YES)] markAsStatic:NO error:NULL]);
        printf("ep functionBlocks count (mutable): %lu\n", (unsigned long)ep.mutableFunctionBlocks.count);
        MIDICIDeviceInfo *ci = [[MIDICIDeviceInfo alloc] initWithDestination:0 manufacturer:[NSData dataWithBytes:"\x01\x02\x03" length:3] family:[NSData dataWithBytes:"\x04\x05" length:2] model:[NSData dataWithBytes:"\x06\x07" length:2] revision:[NSData dataWithBytes:"\x0a\x0b\x0c\x0d" length:4]];
        printf("MIDICIDeviceInfo (3,2,2,4 bytes): %s family=%lu\n", ci ? "yes" : "nil", ci ? (unsigned long)ci.family.length : 0UL);
        MIDICIDeviceInfo *ci2 = [[MIDICIDeviceInfo alloc] initWithDestination:0 manufacturer:[NSData dataWithBytes:"\x01\x02" length:2] family:[NSData dataWithBytes:"\x04\x05" length:2] model:[NSData dataWithBytes:"\x06\x07" length:2] revision:[NSData dataWithBytes:"\x0a\x0b\x0c\x0d" length:4]];
        printf("MIDICIDeviceInfo (manufacturer 2 bytes): %s\n", ci2 ? "yes" : "nil");
    }
    return 0;
}
