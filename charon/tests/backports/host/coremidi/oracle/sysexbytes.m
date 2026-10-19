#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>
#include <stdio.h>

static void show(const char *tag, const MIDIEventPacket *packet, UInt8 group) {
    CFDataRef data = NULL;
    OSStatus status = MIDIEventPacketSysexBytesForGroup(packet, group, &data);
    printf("%-34s group=%u status=%d ", tag, group, (int)status);
    if (data) {
        printf("bytes=");
        const UInt8 *b = CFDataGetBytePtr(data);
        for (CFIndex i = 0; i < CFDataGetLength(data); i++) printf("%02X", b[i]);
        CFRelease(data);
    } else {
        printf("bytes=(null)");
    }
    printf("\n");
}

static void run(const char *tag, const UInt32 *words, int count, UInt8 group) {
    Byte buf[256];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, kMIDIProtocol_2_0);
    MIDIEventListAdd(list, sizeof(buf), p, 0, count, words);
    show(tag, &list->packet[0], group);
}

static void sysex7(UInt32 *out, int status, int count, const UInt8 *data) {
    UInt8 pad[6] = {0, 0, 0, 0, 0, 0};
    for (int i = 0; i < count; i++) pad[i] = data[i];
    out[0] = 0x30000000u | (UInt32)status << 20 | (UInt32)count << 16 | (UInt32)pad[0] << 8 | pad[1];
    out[1] = (UInt32)pad[2] << 24 | (UInt32)pad[3] << 16 | (UInt32)pad[4] << 8 | pad[5];
}

int main(void) {
    UInt32 complete[] = {0x30030102u, 0x03000000u};
    UInt32 start[] = {0x30160102u, 0x03040506u};
    UInt32 cont[] = {0x30260708u, 0x090A0B0Cu};
    UInt32 end[] = {0x30310D00u, 0x00000000u};
    UInt32 emptyEnd[] = {0x30300000u, 0x00000000u};
    UInt32 midi2[] = {0x40903C00u, 0xFFFF0000u};
    run("complete 3 bytes", complete, 2, 0);
    run("complete 3 bytes, group 1", complete, 2, 1);
    run("start 6 bytes", start, 2, 0);
    run("continue 6 bytes", cont, 2, 0);
    run("end 1 byte", end, 2, 0);
    run("end 0 bytes", emptyEnd, 2, 0);
    run("midi 2.0 note on", midi2, 2, 0);
    run("complete, group 15", complete, 2, 15);
    {
        UInt32 words[24];
        for (int m = 0; m < 12; m++) {
            UInt8 data[6];
            for (int i = 0; i < 6; i++) data[i] = (UInt8)(1 + m * 6 + i);
            sysex7(words + 2 * m, 0, 6, data);
        }
        run("12 complete, 6 bytes each", words, 24, 0);
    }
    {
        UInt32 words[24];
        for (int m = 0; m < 12; m++) {
            UInt8 data[6];
            for (int i = 0; i < 6; i++) data[i] = (UInt8)(1 + m * 6 + i);
            int status = m == 0 ? 1 : (m == 11 ? 3 : 2);
            sysex7(words + 2 * m, status, 6, data);
        }
        run("start, 10 continues, end: 66 bytes", words, 24, 0);
    }
    return 0;
}
