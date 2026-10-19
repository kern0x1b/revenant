// The scenario of oracle/eventlistadd.m: what MIDIEventListAdd returns and takes as curPacket, and what it leaves in the list
// when the words do not fit. It is the one text both programs run: eventlistadd.m runs it against the release of macOS
// (recorded in eventlistadd-macos.txt), and differential.m runs it against the library's MIDIEventListInit and MIDIEventListAdd
// and requires the same lines. It touches buffers only: no MIDI object is made. Offsets are from the start of the list buffer.
// The includes of the program that includes this file provide CoreMIDI, <stdio.h> and <string.h>.

static UInt8 gEventListBuffer[256];

static long eventlistadd_offset(const void *p)
{
    return p ? (long)((const UInt8 *)p - gEventListBuffer) : -1;
}

static void eventlistadd_show(FILE *out, const char *what, MIDIEventPacket *result)
{
    MIDIEventList *l = (MIDIEventList *)gEventListBuffer;
    fprintf(out, "%s: result offset %ld, numPackets %u\n", what, eventlistadd_offset(result), (unsigned)l->numPackets);
}

static void eventlistadd_run(FILE *out)
{
    UInt32 w[4] = {0x20903C7F, 0x20803C00, 0x20B00740, 0x20C00100};
    UInt8 *buf = gEventListBuffer;
    MIDIEventList *l = (MIDIEventList *)buf;
    MIDIEventPacket *p, *a, *b;

    fprintf(out, "== what an add returns (list of 256 bytes)\n");
    memset(buf, 0xAA, 256);
    p = MIDIEventListInit(l, kMIDIProtocol_1_0);
    fprintf(out, "init: offset %ld\n", eventlistadd_offset(p));
    a = MIDIEventListAdd(l, 256, p, 5, 1, w);
    eventlistadd_show(out, "first add, time 5, 1 word", a);
    b = MIDIEventListAdd(l, 256, a, 6, 2, w);
    eventlistadd_show(out, "second add, time 6, 2 words", b);
    p = MIDIEventListAdd(l, 256, b, 6, 1, w);
    eventlistadd_show(out, "third add, time 6, 1 word (merged)", p);
    fprintf(out, "last packet wordCount %u\n", (unsigned)((MIDIEventPacket *)(buf + eventlistadd_offset(b)))->wordCount);
    p = MIDIEventListAdd(l, 256, b, 7, 0, w);
    eventlistadd_show(out, "zero words after packets, curPacket the last", p);

    fprintf(out, "== curPacket is the last packet, not the end\n");
    memset(buf, 0xAA, 256);
    p = MIDIEventListInit(l, kMIDIProtocol_1_0);
    a = MIDIEventListAdd(l, 256, p, 5, 1, w);
    b = MIDIEventListAdd(l, 256, a, 6, 1, w);
    p = MIDIEventListAdd(l, 256, a, 7, 1, w);
    eventlistadd_show(out, "add with the first packet as curPacket (it was not the last)", p);
    fprintf(out, "offset 24 timeStamp %llu wordCount %u\n", *(unsigned long long *)(buf + 24), (unsigned)*(UInt32 *)(buf + 32));

    fprintf(out, "== an empty list with a curPacket that is not the first packet's place\n");
    memset(buf, 0xAA, 256);
    p = MIDIEventListInit(l, kMIDIProtocol_1_0);
    p = MIDIEventListAdd(l, 256, (MIDIEventPacket *)(buf + 40), 5, 1, w);
    eventlistadd_show(out, "empty list, curPacket at offset 40", p);
    fprintf(out, "offset 8 timeStamp %llu, offset 40 timeStamp %llu\n", *(unsigned long long *)(buf + 8),
            *(unsigned long long *)(buf + 40));

    fprintf(out, "== what a refused add leaves\n");
    memset(buf, 0xAA, 256);
    p = MIDIEventListInit(l, kMIDIProtocol_1_0);
    a = MIDIEventListAdd(l, 24, p, 5, 1, w);
    eventlistadd_show(out, "one packet into 24 bytes (8 + 16)", a);
    p = MIDIEventListAdd(l, 24, a, 5, 1, w);
    eventlistadd_show(out, "merge of 1 word into 24 bytes, full", p);
    fprintf(out, "packet wordCount %u\n", (unsigned)((MIDIEventPacket *)(buf + 8))->wordCount);
    p = MIDIEventListAdd(l, 24, a, 6, 1, w);
    eventlistadd_show(out, "new packet into 24 bytes, full", p);
    p = MIDIEventListAdd(l, 27, a, 5, 1, w);
    eventlistadd_show(out, "merge into 27 bytes", p);
    p = MIDIEventListAdd(l, 28, a, 5, 1, w);
    eventlistadd_show(out, "merge into 28 bytes (8 + 12 + 8)", p);
}
