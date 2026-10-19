#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
int main(void) {
    @autoreleasepool {
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("mici"), &client, ^(const MIDINotification *m) {});
        MIDIEndpointRef dest = 0;
        MIDIDestinationCreateWithProtocol(client, CFSTR("mici-dst"), kMIDIProtocol_2_0, &dest, ^(const MIDIEventList *l, void *r) {});
        NSData *man3 = [NSData dataWithBytes:"\x01\x02\x03" length:3], *man2 = [NSData dataWithBytes:"\x01\x02" length:2];
        NSData *fam2 = [NSData dataWithBytes:"\x04\x05" length:2], *mod2 = [NSData dataWithBytes:"\x06\x07" length:2];
        NSData *rev4 = [NSData dataWithBytes:"\x0a\x0b\x0c\x0d" length:4];
        MIDICIDeviceInfo *a = [[MIDICIDeviceInfo alloc] initWithDestination:dest manufacturer:man3 family:fam2 model:mod2 revision:rev4];
        printf("device info, real destination, 3/2/2/4 bytes: %s\n", a ? "yes" : "nil");
        if (a) printf("  family length %lu model length %lu\n", (unsigned long)a.family.length, (unsigned long)a.modelNumber.length);
        MIDICIDeviceInfo *b = [[MIDICIDeviceInfo alloc] initWithDestination:dest manufacturer:man2 family:fam2 model:mod2 revision:rev4];
        printf("device info, real destination, manufacturer 2 bytes: %s\n", b ? "yes" : "nil");
        MIDICIDeviceInfo *c = [[MIDICIDeviceInfo alloc] initWithDestination:dest manufacturer:man3 family:fam2 model:mod2 revision:[NSData dataWithBytes:"\x0a" length:1]];
        printf("device info, revision 1 byte: %s\n", c ? "yes" : "nil");
        MIDICIProfile *p = [[MIDICIProfile alloc] initWithData:[NSData dataWithBytes:"\x7e\x00\x01\x02\x03" length:5]];
        printf("profile without a name: %s name=%s\n", p ? "yes" : "nil", p && p.name ? [p.name UTF8String] : "(nil)");
        MIDICIDiscoveryManager *m = [MIDICIDiscoveryManager sharedInstance];
        __block int called = 0; __block NSUInteger count = 99;
        [m discoverWithHandler:^(NSArray *nodes) { called++; count = nodes.count; }];
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 6.0, false);
        printf("discovery handler called %d time(s), nodes %lu\n", called, (unsigned long)count);
        MIDICIResponder *r = [[MIDICIResponder alloc] initWithDeviceInfo:a profileDelegate:nil profileStates:@[] supportProperties:NO];
        printf("responder created: %s\n", r ? "yes" : "nil");
        if (r) printf("responder start: %d\n", (int)[r start]);
        if (r) [r stop];
    }
    return 0;
}
