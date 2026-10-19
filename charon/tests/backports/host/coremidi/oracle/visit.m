#import <CoreMIDI/CoreMIDI.h>
#include <stdio.h>
#include <string.h>

static void visit(void *context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
    const unsigned char *b = (const unsigned char *)&message;
    printf("  ts=%llu bytes=", (unsigned long long)timeStamp);
    for (size_t i = 0; i < sizeof(message); i++) printf("%02X", b[i]);
    printf("\n");
}

static void run(const char *tag, const UInt32 *words, int count) {
    Byte buf[256];
    MIDIEventList *list = (MIDIEventList *)buf;
    MIDIEventPacket *p = MIDIEventListInit(list, count >= 4 ? kMIDIProtocol_2_0 : kMIDIProtocol_1_0);
    MIDIEventListAdd(list, sizeof(buf), p, 42, count, words);
    printf("%s in:", tag);
    for (int i = 0; i < count; i++) printf(" %08X", words[i]);
    printf("\n");
    MIDIEventListForEachEvent(list, visit, NULL);
}

int main(void) {
    run("utility noop", (UInt32[]){0x00000000u}, 1);
    run("utility jr clock", (UInt32[]){0x00100ABCu}, 1);
    run("system timecode", (UInt32[]){0x10F10500u}, 1);
    run("system song position", (UInt32[]){0x10F20102u}, 1);
    run("system song select", (UInt32[]){0x10F30500u}, 1);
    run("system clock", (UInt32[]){0x10F80000u}, 1);
    run("cv1 note on", (UInt32[]){0x20903C7Fu}, 1);
    run("cv1 cc", (UInt32[]){0x20B00740u}, 1);
    run("cv1 program", (UInt32[]){0x20C00500u}, 1);
    run("cv1 pitch bend", (UInt32[]){0x20E00040u}, 1);
    run("cv1 channel pressure", (UInt32[]){0x20D07F00u}, 1);
    run("cv1 poly pressure", (UInt32[]){0x20A03C40u}, 1);
    run("sysex7 complete 3", (UInt32[]){0x30030102u, 0x03000000u}, 2);
    run("sysex7 start 6", (UInt32[]){0x30160102u, 0x03040506u}, 2);
    run("sysex7 end 1", (UInt32[]){0x30310700u, 0x00000000u}, 2);
    run("cv2 note on attr 1", (UInt32[]){0x40903C01u, 0x80001234u}, 2);
    run("cv2 note off", (UInt32[]){0x40803C00u, 0x00000000u}, 2);
    run("cv2 poly pressure", (UInt32[]){0x40A03C00u, 0x12345678u}, 2);
    run("cv2 cc", (UInt32[]){0x40B00700u, 0x80000000u}, 2);
    run("cv2 program bank", (UInt32[]){0x40C00001u, 0x05000A03u}, 2);
    run("cv2 channel pressure", (UInt32[]){0x40D00000u, 0x7FFFFFFFu}, 2);
    run("cv2 pitch bend", (UInt32[]){0x40E00000u, 0x80000000u}, 2);
    run("cv2 per-note pitch bend", (UInt32[]){0x40603C00u, 0x40000000u}, 2);
    run("cv2 per-note management", (UInt32[]){0x40F03C00u, 0x00000001u}, 2);
    run("cv2 rpn", (UInt32[]){0x40200000u, 0x00400000u}, 2);
    run("cv2 nrpn", (UInt32[]){0x40300123u, 0x00400000u}, 2);
    run("cv2 assignable per-note", (UInt32[]){0x40103C00u, 0x40000000u}, 2);
    run("sysex8 start", (UInt32[]){0x50010102u, 0x03040506u, 0x07080000u, 0x00000000u}, 4);
    run("flex data", (UInt32[]){0xD0000000u, 0x00000000u, 0x00000000u, 0x00000000u}, 4);
    run("ump stream", (UInt32[]){0xF0000000u, 0x00000000u, 0x00000000u, 0x00000000u}, 4);
    run("unknown type 6", (UInt32[]){0x60000000u}, 1);
    return 0;
}
