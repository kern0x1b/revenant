#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
int main(void) {
    @autoreleasepool {
        NSArray *ci = [MIDICIDeviceManager.sharedInstance discoveredCIDevices];
        printf("MIDICIDeviceManager discoveredCIDevices count %lu\n", (unsigned long)ci.count);
        NSArray *ump = [MIDIUMPEndpointManager.sharedInstance UMPEndpoints];
        printf("MIDIUMPEndpointManager UMPEndpoints count %lu\n", (unsigned long)ump.count);
        MIDI2DeviceManufacturer man = {{0x12, 0x34, 0x56}}; MIDI2DeviceRevisionLevel rev = {{0x03, 0x04, 0x05, 0x06}};
        MIDI2DeviceInfo *info = [[MIDI2DeviceInfo alloc] initWithManufacturerID:man family:0x1234 modelNumber:0x0102 revisionLevel:rev];
        printf("MIDI2DeviceInfo manufacturerID=%02x%02x%02x family=%x model=%x revision=%02x%02x%02x%02x\n", info.manufacturerID.sysExIDByte[0], info.manufacturerID.sysExIDByte[1], info.manufacturerID.sysExIDByte[2], (unsigned)info.family, (unsigned)info.modelNumber, info.revisionLevel.revisionLevel[0], info.revisionLevel.revisionLevel[1], info.revisionLevel.revisionLevel[2], info.revisionLevel.revisionLevel[3]);
        MIDIUMPMutableFunctionBlock *fb = [[MIDIUMPMutableFunctionBlock alloc] initWithName:@"fb" direction:0 firstGroup:0 totalGroupsSpanned:1 maxSysEx8Streams:0 MIDI1Info:0 UIHint:0 isEnabled:YES];
        printf("MIDIUMPMutableFunctionBlock created: %s\n", fb ? "yes" : "nil");
        if (fb) printf("  name=%s firstGroup=%u groups=%u enabled=%d\n", [fb.name UTF8String], (unsigned)fb.firstGroup, (unsigned)fb.totalGroupsSpanned, (int)fb.isEnabled);
        MIDIUMPMutableEndpoint *ep = [[MIDIUMPMutableEndpoint alloc] initWithName:@"ep" deviceInfo:info productInstanceID:@"pid" MIDIProtocol:kMIDIProtocol_2_0 destinationCallback:^(const MIDIEventList *l, void *r) {}];
        printf("MIDIUMPMutableEndpoint created: %s\n", ep ? "yes" : "nil");
        if (ep) printf("  name=%s protocol=%d enabled=%d destination=%u source=%u\n", [ep.name UTF8String], (int)ep.MIDIProtocol, (int)ep.isEnabled, (unsigned)ep.MIDIDestination, (unsigned)ep.MIDISource);
        MIDICIDeviceInfo *ci2 = [[MIDICIDeviceInfo alloc] initWithDestination:0 manufacturer:[NSData dataWithBytes:"\x01\x02\x03" length:3] family:[NSData dataWithBytes:"\x04\x05" length:2] model:[NSData dataWithBytes:"\x06\x07\x08\x09" length:4] revision:[NSData dataWithBytes:"\x0a" length:1]];
        printf("MIDICIDeviceInfo created: %s family-length=%lu\n", ci2 ? "yes" : "nil", (unsigned long)ci2.family.length);
        MIDICIProfile *p = [[MIDICIProfile alloc] initWithData:[NSData dataWithBytes:"\x7e\x00\x01\x02\x03" length:5] name:@"profile"];
        printf("MIDICIProfile created: %s name=%s id-length=%lu\n", p ? "yes" : "nil", p ? [p.name UTF8String] : "-", p ? (unsigned long)p.profileID.length : 0UL);
    }
    return 0;
}
