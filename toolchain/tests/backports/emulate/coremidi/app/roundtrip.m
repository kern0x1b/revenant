#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static volatile int gDestinationPackets;
static volatile int gInputPackets;
static UInt32 gDestinationWords[2];
static UInt32 gInputWords[2];
static int gDestinationCount;
static int gInputCount;

static int gFailures;

static void expect(int ok, const char *line)
{
    if (!ok)
        gFailures++;
    printf("%s %s\n", ok ? "ok  " : "FAIL", line);
}

int revenant_roundtrip_run(void)
{
    @autoreleasepool {
        MIDIClientRef client = 0;
        OSStatus status = MIDIClientCreateWithBlock(CFSTR("revenant-roundtrip"), &client, ^(const MIDINotification *message) {});
        printf("client          %s\n", status == noErr ? "noErr" : "error");
        expect(status == noErr, "MIDIClientCreateWithBlock returned noErr");

        MIDIEndpointRef destination = 0;
        status = MIDIDestinationCreateWithProtocol(client, CFSTR("revenant-destination"), kMIDIProtocol_2_0, &destination,
            ^(const MIDIEventList *list, void *srcConnRefCon) {
                const MIDIEventPacket *packet = &list->packet[0];
                gDestinationCount = (int)list->numPackets;
                if (list->numPackets > 0 && packet->wordCount >= 2) {
                    gDestinationWords[0] = packet->words[0];
                    gDestinationWords[1] = packet->words[1];
                }
                gDestinationPackets++;
            });
        printf("destination status %d\n", (int)status);
        expect(status == noErr, "MIDIDestinationCreateWithProtocol returned noErr");

        MIDIEndpointRef source = 0;
        status = MIDISourceCreateWithProtocol(client, CFSTR("revenant-source"), kMIDIProtocol_2_0, &source);
        printf("source status   %d\n", (int)status);
        expect(status == noErr, "MIDISourceCreateWithProtocol returned noErr");

        MIDIEndpointRef plainSource = 0;
        OSStatus plain = MIDISourceCreate(client, CFSTR("revenant-plain-source"), &plainSource);
        printf("control status  %d (release MIDISourceCreate)\n", (int)plain);

        SInt32 protocol = 0;
        MIDIObjectGetIntegerProperty(destination, kMIDIPropertyProtocolID, &protocol);
        printf("destination     %s\n", protocol == kMIDIProtocol_2_0 ? "2.0" : "not 2.0");
        expect(protocol == kMIDIProtocol_2_0, "the destination's protocol property reads 2.0");
        protocol = 0;
        MIDIObjectGetIntegerProperty(source, kMIDIPropertyProtocolID, &protocol);
        printf("source          %s\n", protocol == kMIDIProtocol_2_0 ? "2.0" : "not 2.0");
        expect(protocol == kMIDIProtocol_2_0, "the source's protocol property reads 2.0");

        MIDIPortRef input = 0;
        status = MIDIInputPortCreateWithProtocol(client, CFSTR("revenant-input"), kMIDIProtocol_1_0, &input,
            ^(const MIDIEventList *list, void *srcConnRefCon) {
                const MIDIEventPacket *packet = &list->packet[0];
                gInputCount = (int)list->numPackets;
                if (list->numPackets > 0 && packet->wordCount >= 1)
                    gInputWords[0] = packet->words[0];
                gInputPackets++;
            });
        expect(status == noErr, "MIDIInputPortCreateWithProtocol returned noErr");
        status = MIDIPortConnectSource(input, source, NULL);
        expect(status == noErr, "MIDIPortConnectSource returned noErr");

        MIDIPortRef output = 0;
        status = MIDIOutputPortCreate(client, CFSTR("revenant-output"), &output);
        expect(status == noErr, "MIDIOutputPortCreate returned noErr");

        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 note[2] = {0x40903C00u, 0xFFFF0000u};
        MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
        packet = MIDIEventListAdd(list, sizeof(buffer), packet, 0, 2, note);
        expect(packet != NULL, "MIDIEventListAdd took the note");
        status = MIDISendEventList(output, destination, list);
        printf("sent            %s\n", status == noErr ? "noErr" : "error");
        expect(status == noErr, "MIDISendEventList returned noErr");

        UInt32 one[1] = {0x20903C7Fu};
        MIDIEventList *out = (MIDIEventList *)buffer;
        MIDIEventPacket *outPacket = MIDIEventListInit(out, kMIDIProtocol_1_0);
        MIDIEventListAdd(out, sizeof(buffer), outPacket, 0, 1, one);
        status = MIDIReceivedEventList(source, out);
        expect(status == noErr, "MIDIReceivedEventList returned noErr");

        for (int waited = 0; waited < 40 && (gDestinationPackets == 0 || gInputPackets == 0); waited++)
            usleep(100000);

        int received = gDestinationPackets > 0 && gDestinationWords[0] == 0x40903C00u && gDestinationWords[1] == 0xFFFF0000u;
        printf("received        %d packet(s): %08X %08X\n", gDestinationCount, (unsigned int)gDestinationWords[0], (unsigned int)gDestinationWords[1]);
        expect(received, "the destination received 40903C00 FFFF0000");

        int inputOK = gInputPackets > 0 && gInputWords[0] == 0x20903C7Fu;
        printf("input           %d packet(s): %08X\n", gInputCount, (unsigned int)gInputWords[0]);
        expect(inputOK, "the input port received 20903C7F");

        printf("roundtrip: %s (%d failure%s)\n", gFailures ? "FAIL" : "PASS", gFailures, gFailures == 1 ? "" : "s");
        fflush(stdout);
        return gFailures ? 1 : 0;
    }
}
