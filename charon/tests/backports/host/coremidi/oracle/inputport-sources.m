#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

static void readBlock(const MIDIPacketList *pl, void *srcConnRefCon) {
    printf("    read block: srcConnRefCon %ld, %u packet(s)\n", (long)srcConnRefCon, (unsigned)pl->numPackets);
    const MIDIPacket *p = &pl->packet[0];
    for (UInt32 i = 0; i < pl->numPackets; i++) {
        printf("      packet ts=%llu bytes", (unsigned long long)p->timeStamp);
        for (UInt16 b = 0; b < p->length; b++) printf(" %02X", (unsigned)p->data[b]);
        printf("\n");
        p = MIDIPacketNext(p);
    }
}

static void settle(void) {
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.4, false);
}

static void receive(const char *label, MIDIEndpointRef src, const Byte *bytes, ByteCount n) {
    Byte buf[256];
    MIDIPacketList *pl = (MIDIPacketList *)buf;
    MIDIPacket *p = MIDIPacketListInit(pl);
    p = MIDIPacketListAdd(pl, sizeof(buf), p, 0, n, bytes);
    printf("send %s:", label);
    for (ByteCount i = 0; i < n; i++) printf(" %02X", (unsigned)bytes[i]);
    printf(" (MIDIPacketListAdd %s)\n", p ? "ok" : "NULL");
    OSStatus s = MIDIReceived(src, pl);
    printf("    MIDIReceived status %d\n", (int)s);
    settle();
}

int main(void) {
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);
        MIDIClientRef client = 0;
        MIDIClientCreateWithBlock(CFSTR("inputport-sources"), &client, ^(const MIDINotification *m) {});
        MIDIPortRef port = 0;
        MIDIInputPortCreateWithBlock(client, CFSTR("ips-in"), &port, ^(const MIDIPacketList *pl, void *ref) { readBlock(pl, ref); });
        MIDIEndpointRef srcA = 0, srcB = 0;
        MIDISourceCreate(client, CFSTR("ips-A"), &srcA);
        MIDISourceCreate(client, CFSTR("ips-B"), &srcB);
        settle();
        printf("connect A with refCon 1: status %d\n", (int)MIDIPortConnectSource(port, srcA, (void *)1));
        printf("connect B with refCon 2: status %d\n", (int)MIDIPortConnectSource(port, srcB, (void *)2));
        settle();

        printf("== run 1: arrival order A, B, A\n");
        const Byte a1[] = {0xF0, 0x01};
        const Byte b1[] = {0x90, 0x3C, 0x7F};
        const Byte a2[] = {0x02, 0xF7};
        receive("from A", srcA, a1, 2);
        receive("from B", srcB, b1, 3);
        receive("from A", srcA, a2, 2);

        printf("== run 2: arrival order A, A, B, A\n");
        const Byte a3[] = {0xF0};
        const Byte a4[] = {0x01};
        receive("from A", srcA, a3, 1);
        receive("from A", srcA, a4, 1);
        receive("from B", srcB, b1, 3);
        receive("from A", srcA, a2, 2);

        printf("== run 3 (extra): running status test, A note then A data-only, then B data-only\n");
        const Byte a5[] = {0x90, 0x3C, 0x7F};
        const Byte a6[] = {0x40, 0x7F};
        const Byte b2[] = {0x41, 0x7F};
        receive("from A", srcA, a5, 3);
        receive("from A", srcA, a6, 2);
        receive("from B", srcB, b2, 2);

        printf("== disconnect, dispose\n");
        printf("disconnect A: status %d\n", (int)MIDIPortDisconnectSource(port, srcA));
        printf("disconnect B: status %d\n", (int)MIDIPortDisconnectSource(port, srcB));
        settle();
        MIDIPortDispose(port);
        MIDIEndpointDispose(srcA);
        MIDIEndpointDispose(srcB);
        MIDIClientDispose(client);
        printf("== done\n");
    }
    return 0;
}
