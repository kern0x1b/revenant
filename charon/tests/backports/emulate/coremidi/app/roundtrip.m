//
//  app/roundtrip.m
//  The CoreMIDI backport on the emulated iPhone 4S at 6.1.3: a client with a block, a virtual source and a
//  virtual destination that speaks Universal MIDI Packets, a protocol-aware input port, and a message that goes
//  out of the source and comes back in both places. It is run by the application (app/main.m, run-app.sh). It has
//  no command-line form: the release refuses a command-line process its virtual endpoints (-10844), so the
//  round trip is measured only as an application (facts/CoreMIDI/CoreMIDI.md).
//
//  What it prints, one line each, and what each line must say for the round trip to hold:
//
//      client          noErr          the client was made with its block
//      destination     2.0            the destination's protocol is the one asked for, read back
//      source          2.0            the same for the source
//      sent            noErr          MIDISendEventList accepted a MIDI 2.0 note on, velocity 0xFFFF
//      received        1 packet: 40903C00 FFFF0000    the destination's block got the note as 2.0 words
//      input           1 packet: 20903C7F             the input port (1.0) got the source's list as 1.0 words
//
//  and exits 0 only if every line matched. The release has no protocol API, so each line that says 2.0 is the
//  library's answer; the note's words are measured against macOS CoreMIDI (facts/CoreMIDI/Translation.md).
//

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

int charon_roundtrip_run(void)
{
    @autoreleasepool {
        MIDIClientRef client = 0;
        OSStatus status = MIDIClientCreateWithBlock(CFSTR("charon-roundtrip"), &client, ^(const MIDINotification *message) {});
        printf("client          %s\n", status == noErr ? "noErr" : "error");
        expect(status == noErr, "MIDIClientCreateWithBlock returned noErr");

        MIDIEndpointRef destination = 0;
        status = MIDIDestinationCreateWithProtocol(client, CFSTR("charon-destination"), kMIDIProtocol_2_0, &destination,
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
        status = MIDISourceCreateWithProtocol(client, CFSTR("charon-source"), kMIDIProtocol_2_0, &source);
        printf("source status   %d\n", (int)status);
        expect(status == noErr, "MIDISourceCreateWithProtocol returned noErr");

        // The release's own virtual source, with no library in the way: the control for the line above.
        MIDIEndpointRef plainSource = 0;
        OSStatus plain = MIDISourceCreate(client, CFSTR("charon-plain-source"), &plainSource);
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
        status = MIDIInputPortCreateWithProtocol(client, CFSTR("charon-input"), kMIDIProtocol_1_0, &input,
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
        status = MIDIOutputPortCreate(client, CFSTR("charon-output"), &output);
        expect(status == noErr, "MIDIOutputPortCreate returned noErr");

        // A MIDI 2.0 note on, channel 0, note 60, velocity 0xFFFF, to the 2.0 destination.
        Byte buffer[256];
        MIDIEventList *list = (MIDIEventList *)buffer;
        UInt32 note[2] = {0x40903C00u, 0xFFFF0000u};
        MIDIEventPacket *packet = MIDIEventListInit(list, kMIDIProtocol_2_0);
        packet = MIDIEventListAdd(list, sizeof(buffer), packet, 0, 2, note);
        expect(packet != NULL, "MIDIEventListAdd took the note");
        status = MIDISendEventList(output, destination, list);
        printf("sent            %s\n", status == noErr ? "noErr" : "error");
        expect(status == noErr, "MIDISendEventList returned noErr");

        // A MIDI 1.0 note on out of the source, to the input port that is connected to it.
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
