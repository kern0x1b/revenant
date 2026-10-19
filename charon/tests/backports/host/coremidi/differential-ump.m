#import <Foundation/Foundation.h>
#include <stdio.h>
#include "CharonMIDIUMP18.h"
#include "CharonCoreMIDI.h"
#include "CharonMIDICI.h"

static int gUMPChecks;
static int gUMPFailures;

static void check(int passed, const char *name, const char *detail)
{
    gUMPChecks++;
    if (passed) {
        printf("ok %s\n", name);
    } else {
        gUMPFailures++;
        printf("FAIL %s: %s\n", name, detail);
    }
}

static void check_mici_classes(void)
{
    charon_host_MIDICIDiscoveryManager *manager = [charon_host_MIDICIDiscoveryManager sharedInstance];
    __block int handlerCalls = 0;
    [manager discoverWithHandler:^(NSArray *nodes) { handlerCalls++; }];
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, false);
    check(handlerCalls == 0, "MIDI-CI discovery: the handler is never called, as macOS (refused client)", "");

    MIDIClientRef client = 0;
    MIDIClientCreateWithBlock(CFSTR("ci-check"), &client, NULL);
    MIDIEndpointRef destination = 0;
    CharonMIDIDestination(client, CFSTR("ci-destination"), kMIDIProtocol_2_0, &destination, ^(const MIDIEventList *l, void *r) {});
    NSData *man3 = [NSData dataWithBytes:"\x01\x02\x03" length:3], *man2 = [NSData dataWithBytes:"\x01\x02" length:2];
    NSData *fam2 = [NSData dataWithBytes:"\x04\x05" length:2], *mod2 = [NSData dataWithBytes:"\x06\x07" length:2];
    NSData *rev4 = [NSData dataWithBytes:"\x0a\x0b\x0c\x0d" length:4], *rev1 = [NSData dataWithBytes:"\x0a" length:1];
    charon_host_MIDICIDeviceInfo *info = [[charon_host_MIDICIDeviceInfo alloc] initWithDestination:destination manufacturer:man3
                                                                                              family:fam2 model:mod2 revision:rev4];
    check(info != nil && info.family.length == 2 && info.modelNumber.length == 2, "MIDI-CI device info made with 3/2/2/4 bytes, as macOS", "");
    check([[charon_host_MIDICIDeviceInfo alloc] initWithDestination:destination manufacturer:man2 family:fam2 model:mod2 revision:rev4] == nil,
          "MIDI-CI device info refused for a 2-byte manufacturer, as macOS", "");
    check([[charon_host_MIDICIDeviceInfo alloc] initWithDestination:destination manufacturer:man3 family:fam2 model:mod2 revision:rev1] == nil,
          "MIDI-CI device info refused for a 1-byte revision, as macOS", "");
    check([[charon_host_MIDICIDeviceInfo alloc] initWithDestination:0 manufacturer:man3 family:fam2 model:mod2 revision:rev4] == nil,
          "MIDI-CI device info refused for no destination, as macOS", "");

    charon_host_MIDICIProfile *profile = [[charon_host_MIDICIProfile alloc] initWithData:[NSData dataWithBytes:"\x7e\x00\x01\x02\x03" length:5]];
    check(profile != nil && [profile.name isEqualToString:@"Standard Profile Bank 0x00 Number 0x01, Version: 0x02 Level: 0x03"] &&
          profile.profileID.length == 5, "MIDI-CI profile named from its standard bytes, as macOS", "");

    id noDelegate = nil;
    check([[charon_host_MIDICIResponder alloc] initWithDeviceInfo:info profileDelegate:noDelegate profileStates:@[] supportProperties:NO] == nil,
          "MIDI-CI responder with no delegate is not made, as macOS", "");
}

static int gSendCompletions;
static void charon_send_completed(MIDISysexSendRequestUMP *request)
{
    gSendCompletions++;
}

static UInt32 gReceived[8];
static UInt32 gReceivedCount;
static void charon_record_words(const MIDIEventList *list, void *ref)
{
    gReceivedCount = 0;
    const MIDIEventPacket *p = &list->packet[0];
    for (UInt32 i = 0; i < list->numPackets; i++) {
        for (UInt32 w = 0; w < p->wordCount && gReceivedCount < 8; w++)
            gReceived[gReceivedCount++] = p->words[w];
        p = MIDIEventPacketNext(p);
    }
}

static void check_ump_sysex_sends(void)
{
    MIDIClientRef client = 0;
    MIDIClientCreateWithBlock(CFSTR("ump-sysex-check"), &client, NULL);
    MIDIEndpointRef destination = 0;
    CharonMIDIDestination(client, CFSTR("ump-sysex-destination"), kMIDIProtocol_2_0, &destination, ^(const MIDIEventList *l, void *r) {
        charon_record_words(l, r);
    });
    UInt32 sysex7[2] = {0x30030102u, 0x03000000u};
    MIDISysexSendRequestUMP request;
    memset(&request, 0, sizeof(request));
    request.destination = destination;
    request.words = sysex7;
    request.wordsToSend = 2;
    request.completionProc = charon_send_completed;
    gSendCompletions = 0;
    gReceivedCount = 0;
    OSStatus status = MIDISendUMPSysex(&request);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
    check(status == noErr && request.wordsToSend == 0 && request.complete && gSendCompletions == 1,
          "UMP sysex7 send: noErr, count used up, complete, completion once (umpsysend-macos.txt)", "");
    check(gReceivedCount == 2 && gReceived[0] == 0x30030102u && gReceived[1] == 0x03000000u,
          "UMP sysex7 send: the destination receives the words verbatim", "");

    UInt32 sysex8[4] = {0x50010102u, 0x03040506u, 0x07080000u, 0x00000000u};
    memset(&request, 0, sizeof(request));
    request.destination = destination;
    request.words = sysex8;
    request.wordsToSend = 4;
    request.completionProc = charon_send_completed;
    gSendCompletions = 0;
    gReceivedCount = 0;
    status = MIDISendUMPSysex8(&request);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
    check(status == noErr && gSendCompletions == 1 && gReceivedCount == 4 && gReceived[0] == 0x50010102u && gReceived[3] == 0x00000000u,
          "UMP sysex8 send: the destination receives the four words verbatim, as macOS does for a 2.0 destination", "");

    memset(&request, 0, sizeof(request));
    request.destination = 0;
    request.words = sysex7;
    request.wordsToSend = 2;
    request.completionProc = charon_send_completed;
    gSendCompletions = 0;
    status = MIDISendUMPSysex(&request);
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
    check(status == noErr && gSendCompletions == 1, "UMP send to no destination: noErr and the completion runs, as macOS", "");

    memset(&request, 0, sizeof(request));
    request.destination = destination;
    request.words = sysex7;
    request.wordsToSend = 0;
    request.completionProc = charon_send_completed;
    gSendCompletions = 0;
    gReceivedCount = 0;
    status = MIDISendUMPSysex(&request);
    check(status == noErr && gSendCompletions == 1 && gReceivedCount == 0, "UMP send of zero words: noErr, completion, nothing delivered", "");
}

static void check_ump_classes(void)
{
    check([[charon_host_MIDICIDeviceManager sharedInstance] discoveredCIDevices].count == 0,
          "MIDI-CI: no device discovered, as macOS (umpclasses-macos.txt)", "");
    check([[charon_host_MIDIUMPEndpointManager sharedInstance] UMPEndpoints].count == 0,
          "UMP: no endpoint listed before one is made, as macOS", "");

    MIDI2DeviceManufacturer man = {{0x12, 0x34, 0x56}};
    MIDI2DeviceRevisionLevel rev = {{0x03, 0x04, 0x05, 0x06}};
    charon_host_MIDI2DeviceInfo *info = [[charon_host_MIDI2DeviceInfo alloc] initWithManufacturerID:man family:0x1234
                                                                                       modelNumber:0x0102 revisionLevel:rev];
    check(info.manufacturerID.sysExIDByte[2] == 0x56 && info.family == 0x1234 && info.modelNumber == 0x0102 &&
          info.revisionLevel.revisionLevel[3] == 0x06,
          "MIDI2DeviceInfo keeps its values, as macOS prints them", "");

    charon_host_MIDIUMPMutableFunctionBlock *fb = [[charon_host_MIDIUMPMutableFunctionBlock alloc]
        initWithName:@"fb" direction:kMIDIUMPFunctionBlockDirectionInput firstGroup:0 totalGroupsSpanned:1
        maxSysEx8Streams:0 MIDI1Info:kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 UIHint:kMIDIUMPFunctionBlockUIHintUnknown isEnabled:YES];
    check(fb != nil && [fb.name isEqualToString:@"fb"] && fb.firstGroup == 0 && fb.totalGroupsSpanned == 1 && fb.isEnabled,
          "function block made with the values macOS gives (umpclasses-macos.txt)", "");
    check(![fb setEnabled:YES error:NULL] && ![fb setName:@"x" error:NULL],
          "function block not registered: setters answer NO, as macOS (umpclasses2-macos.txt)", "");
    check(fb.UMPEndpoint == nil, "function block not registered has no endpoint", "");

    charon_host_MIDI2DeviceInfo *endpointInfo = info;
    charon_host_MIDIUMPMutableEndpoint *ep = [[charon_host_MIDIUMPMutableEndpoint alloc] initWithName:@"ep" deviceInfo:endpointInfo
        productInstanceID:@"pid" MIDIProtocol:kMIDIProtocol_2_0 destinationCallback:^(const MIDIEventList *list, void *ref) {}];
    check(ep != nil, "client endpoint made (macOS: created, umpclasses-macos.txt)", "");
    if (ep) {
        check(!ep.isEnabled && ep.MIDIProtocol == kMIDIProtocol_2_0 && [ep.name isEqualToString:@"ep"] &&
              ep.MIDIDestination != 0 && ep.MIDISource != 0, "client endpoint: disabled, protocol 2.0, named, has both ends", "");
        check([[charon_host_MIDIUMPEndpointManager sharedInstance] UMPEndpoints].count == 1,
              "the manager lists the disabled client endpoint, as macOS (umpclasses2-macos.txt: 1)", "");
        check([ep setName:@"renamed" error:NULL] && [ep.name isEqualToString:@"renamed"],
              "endpoint setName answers YES, as macOS", "");
        CFStringRef serverName = NULL;
        OSStatus serverStatus = MIDIObjectGetStringProperty(ep.MIDIDestination, kMIDIPropertyName, &serverName);
        check(serverStatus == noErr && serverName && [(__bridge NSString *)serverName isEqualToString:@"renamed"],
              "endpoint setName changes the release's name of the endpoint (kMIDIPropertyName)", "");
        if (serverName)
            CFRelease(serverName);
        check([ep setEnabled:YES error:NULL] && ep.isEnabled, "endpoint setEnabled:YES answers YES, as macOS", "");
        check([ep registerFunctionBlocks:@[fb] markAsStatic:NO error:NULL] && ep.functionBlocks.count == 1,
              "endpoint registers a block and lists it, as macOS", "");
        check(!ep.hasStaticFunctionBlocks, "endpoint is not static after markAsStatic:NO, as macOS", "");
        check([ep registerFunctionBlocks:@[fb] markAsStatic:YES error:NULL] && ep.hasStaticFunctionBlocks,
              "endpoint is static after markAsStatic:YES, as macOS", "");
        charon_host_MIDIUMPMutableFunctionBlock *b1 = [[charon_host_MIDIUMPMutableFunctionBlock alloc]
            initWithName:@"b1" direction:kMIDIUMPFunctionBlockDirectionInput firstGroup:0 totalGroupsSpanned:1
            maxSysEx8Streams:0 MIDI1Info:kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 UIHint:kMIDIUMPFunctionBlockUIHintUnknown isEnabled:YES];
        charon_host_MIDIUMPMutableFunctionBlock *b2 = [[charon_host_MIDIUMPMutableFunctionBlock alloc]
            initWithName:@"b2" direction:kMIDIUMPFunctionBlockDirectionOutput firstGroup:4 totalGroupsSpanned:1
            maxSysEx8Streams:0 MIDI1Info:kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 UIHint:kMIDIUMPFunctionBlockUIHintUnknown isEnabled:YES];
        charon_host_MIDIUMPMutableFunctionBlock *b3 = [[charon_host_MIDIUMPMutableFunctionBlock alloc]
            initWithName:@"b3" direction:kMIDIUMPFunctionBlockDirectionInput firstGroup:8 totalGroupsSpanned:1
            maxSysEx8Streams:0 MIDI1Info:kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 UIHint:kMIDIUMPFunctionBlockUIHintUnknown isEnabled:YES];
        check([ep registerFunctionBlocks:@[b1, b2, b3] markAsStatic:NO error:NULL] && ep.functionBlocks.count == 3
              && ep.functionBlocks[0].functionBlockID == 1 && ep.functionBlocks[1].functionBlockID == 2 && ep.functionBlocks[2].functionBlockID == 3,
              "function block IDs of three blocks registered together are 1, 2, 3, as macOS", "");
    }
}

int charon_ump_classes_run(int *checks)
{
    @autoreleasepool {
        check_mici_classes();
        check_ump_sysex_sends();
        check_ump_classes();
    }
    *checks = gUMPChecks;
    return gUMPFailures;
}
