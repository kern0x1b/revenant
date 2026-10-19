// Charon's own part of CoreMIDI for the releases that lack the MIDI 2.0 (UMP) API: the translation between
// MIDI 1.0 bytes and Universal MIDI Packets, the event list builder's packet rules, and the per-channel
// state a 2.0 -> 1.0 send keeps. Every name here begins with Charon, so internal_symbol() keeps it out of the
// library's exports; the API files (MIDIEventList14.m, MIDIProtocol14.m, ...) call it and export only what
// CoreMIDI declares.
//
// The rules are the ones macOS CoreMIDI was measured to apply, through virtual endpoints, by
// tests/backports/host/coremidi (run.sh): see facts/CoreMIDI/Translation.md for each rule and its evidence.
#ifndef CharonCoreMIDI_h
#define CharonCoreMIDI_h

#include <Availability.h>
#include <CoreMIDI/MIDIServices.h>
#include <TargetConditionals.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

// The error codes of the Carbon headers (MacErrors.h), which the iOS SDK does not declare: the values are the macOS ones.
enum {
    charon_paramErr = -50,
    charon_memFullErr = -108
};

// The UMP key of a protocol, as this library names it: the iOS SDK marks kMIDIPropertyProtocolID from 14.0, so the port
// uses the string the release answers (oracle/probe2.m prints it: oracle/probe2-macos.txt), declared once here for the three files
// that set it.
#define CHARON_PROTOCOL_KEY CFSTR("protocol")

// The library's own mark on every object it takes (CharonMIDIPorts.m): an integer written under this key when the object is
// taken, and read back to tell the object from a reference the release gave to a new one (the new object has no such key, or
// another value). The key is the library's, so an application that sets the object's UniqueID (the creator's job, documented
// at kMIDIPropertyUniqueID) cannot disturb it.
#define CHARON_OWNER_KEY CFSTR("charon.owner")

// Sizes are summed and multiplied only through these, and only after a check that the result is held by size_t: on armv7
// size_t is 32 bits, so a count from a caller can wrap a plain sum. Each returns 0 (and leaves the value unchanged) when the
// result would not fit, and the caller refuses the work instead of allocating less than it writes.
static inline int charon_size_add(size_t *sum, size_t value)
{
    if (value > SIZE_MAX - *sum)
        return 0;
    *sum += value;
    return 1;
}

static inline int charon_size_mul(size_t *product, size_t count, size_t each)
{
    if (each != 0 && count > SIZE_MAX / each)
        return 0;
    *product = count * each;
    return 1;
}

// The capacity of a table that doubles from capacity (16 when empty) of elements of the given size, or 0 when it cannot be
// doubled in a size_t. A table of objects that are made and disposed grows with them, so its doubling is checked as well.
static inline size_t charon_grown_capacity(size_t capacity, size_t element)
{
    size_t next = 0;
    if (capacity > SIZE_MAX / 2 || !charon_size_mul(&next, capacity ? capacity * 2 : 16, element))
        return 0;
    return capacity ? capacity * 2 : 16;
}

// A growable array of UMP words, filled by the parsers below. failed is set when an allocation fails, and the
// caller then answers with an error rather than with a partial list. A caller that has storage of its own (the stack of a
// read callback) gives it with CharonMIDIWordsUseStorage: the array lives there until it outgrows it, and only then moves to
// the heap (heap is set). A zeroed array is on the heap from its first word. CharonMIDIWordsRelease frees what is on the heap.
typedef struct CharonMIDIWords {
    UInt32 *words;
    size_t count;
    size_t capacity;
    int failed;
    int heap;
} CharonMIDIWords;

// A growable array of MIDI 1.0 bytes, filled by CharonMIDIUMPToBytes, with the same storage rule.
typedef struct CharonMIDIBytes {
    uint8_t *bytes;
    size_t count;
    size_t capacity;
    int failed;
    int heap;
} CharonMIDIBytes;

static inline void CharonMIDIWordsUseStorage(CharonMIDIWords *out, UInt32 *storage, size_t capacity)
{
    out->words = storage;
    out->count = 0;
    out->capacity = capacity;
    out->failed = 0;
    out->heap = 0;
}

static inline void CharonMIDIWordsRelease(CharonMIDIWords *out)
{
    if (out->heap)
        free(out->words);
    out->words = NULL;
    out->heap = 0;
    out->capacity = 0;
}

static inline void CharonMIDIBytesUseStorage(CharonMIDIBytes *out, uint8_t *storage, size_t capacity)
{
    out->bytes = storage;
    out->count = 0;
    out->capacity = capacity;
    out->failed = 0;
    out->heap = 0;
}

static inline void CharonMIDIBytesRelease(CharonMIDIBytes *out)
{
    if (out->heap)
        free(out->bytes);
    out->bytes = NULL;
    out->heap = 0;
    out->capacity = 0;
}

// What a MIDI 1.0 byte stream carries from one packet to the next: the running status, a message whose data
// bytes have not all arrived, and a SysEx begun with F0 that has not met its F7. A SysEx is sent as 6-byte
// UMP chunks, and the last chunk is held back until the SysEx ends, so that a SysEx of six bytes or fewer is
// one complete packet, as it is on macOS. A caller starts each input from a zeroed parser.
typedef struct CharonMIDIParser {
    uint8_t running;
    uint8_t pendingStatus;
    int pendingNeed;
    int pendingHave;
    uint8_t pendingData[2];
    int inSysex;
    int sysexSent;
    uint8_t sysexCount;
    uint8_t sysex[6];
} CharonMIDIParser;

// The registered or non-registered parameter a channel last selected on the 1.0 side. A 2.0 RPN or NRPN
// sends its two selecting controllers only when the parameter differs from this, as macOS does.
typedef struct CharonMIDIRPN {
    int selected;
    int nrpn;
    uint8_t msb;
    uint8_t lsb;
} CharonMIDIRPN;

void CharonMIDIWordsAppend(CharonMIDIWords *out, UInt32 word);

// Parses the MIDI 1.0 bytes of one packet into UMP words of the given group, in the given protocol (1 or 2),
// appending to out. A 1.0 channel message stays a 32-bit word; a 2.0 one becomes its 64-bit channel voice
// message with the value scaled up (CharonMIDIUp16From7, CharonMIDIUp32From7, CharonMIDIUp32From14). A
// real-time byte inside a SysEx sends the SysEx so far, as macOS does.
void CharonMIDIParseBytes(CharonMIDIParser *parser, const uint8_t *data, size_t length, int protocol,
                          uint8_t group, CharonMIDIWords *out);

// Called after the last packet of a list: a SysEx still open sends what it holds, as a start or a continue,
// and stays open for the packets that follow. macOS does the same at the end of a list.
void CharonMIDIParseFlush(CharonMIDIParser *parser, uint8_t group, CharonMIDIWords *out);

// What a Bluetooth LE MIDI stream carries from one notification to the next: whether a timestamp byte is due, a SysEx
// open for its F7, the running status, and a message whose data bytes have not all arrived.
typedef struct CharonBLEParser {
    int timestampDue;
    int afterTimestamp;
    int inSysex;
    uint8_t running;
    int need;
    int have;
} CharonBLEParser;

// Parses one Bluetooth LE MIDI packet into MIDI 1.0 bytes, as the Bluetooth LE MIDI specification frames them: a header
// byte with bit 7 set, then messages, each preceded by a timestamp byte (bit 7 set), which is dropped. A byte with bit 7
// set where a timestamp is due is that timestamp; any other byte with bit 7 set is a status, and a byte without it is
// data, of the running status or of an open SysEx. A packet whose first byte is not a header is dropped. out must hold
// twice length bytes (a running status is sent again with each message's first data byte). Returns the bytes written.
size_t CharonBLEMIDIParse(CharonBLEParser *parser, const uint8_t *data, size_t length, uint8_t *out);

// Converts the UMP words of one event packet to MIDI 1.0 bytes, appending to out. A message with no 1.0
// counterpart (per-note controllers, relative RPN and NRPN, per-note management, unknown types) produces no
// bytes, as it does on macOS. rpn is the per-channel state of the destination the bytes are sent to.
void CharonMIDIUMPToBytes(const UInt32 *words, size_t count, CharonMIDIRPN rpn[16], CharonMIDIBytes *out);

// The number of words the UMP message that begins with word starts: 1, 2, 3 or 4. Zero for a message type the
// translation does not recognise, which then stops the packet it is in.
int CharonMIDIUMPWordCount(UInt32 word);

// MIDI 1.0 to 2.0 value scaling, as measured on macOS: a value at or below the centre is shifted up, and a
// value above it is spread over the rest of the range.
UInt32 CharonMIDIUp16From7(UInt32 value);
UInt32 CharonMIDIUp32From7(UInt32 value);
UInt32 CharonMIDIUp32From14(UInt32 value);

// MIDIEventListAdd as macOS keeps it: curPacket is the list's last packet (what MIDIEventListInit returned while the list
// is empty), an event at the time stamp of that packet is merged into it, and the packet written or merged into is
// returned. NULL if the words do not fit in listSize bytes, with the list unchanged.
MIDIEventPacket *CharonMIDIEventListAdd(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                        MIDITimeStamp time, size_t wordCount, const UInt32 *words);

// The same, for a builder that tracks the list's end itself: curPacket is the end of the list's content, and *last is the
// list's last packet (NULL for an empty list), set to the packet written or merged into after each add. Returns the new
// end, or NULL if the words do not fit. This is the form the library's own builders use.
MIDIEventPacket *CharonMIDIEventListAppend(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                           MIDIEventPacket **last, MIDITimeStamp time, size_t wordCount, const UInt32 *words);

// The protocol-aware ports, endpoints and sends of CharonMIDIPorts.m, which the iOS 14 API files and the iOS 18 classes call.
OSStatus CharonMIDIInputPort(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol, MIDIPortRef *outPort,
                             MIDIReceiveBlock receiveBlock);
OSStatus CharonMIDIDestination(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outDest,
                               MIDIReceiveBlock readBlock);
OSStatus CharonMIDISource(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc);
OSStatus CharonMIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist);
OSStatus CharonMIDIReceive(MIDIEndpointRef src, const MIDIEventList *evtlist);
// Delivers UMP words verbatim to a destination this process made (CharonMIDIPorts.m); NO for any other endpoint.
Boolean CharonMIDIDeliverInProcess(MIDIEndpointRef endpoint, const UInt32 *words, UInt32 count);
// Records the retained block of a port or destination the library made through the release's function form (MIDIBlocks9.m):
// the block is released when the object is gone.
void CharonMIDIOwnBlock(MIDIObjectRef object, void *retainedBlock);
// Drops the route of a reference the library gives to a new object it makes outside CharonMIDIPorts.m (the Bluetooth source).
void CharonMIDIForgetRoute(MIDIObjectRef object);

// The request of MIDISendUMPSysex and MIDISendUMPSysex8, as the 26.2 SDK declares it (MIDIServices.h). An SDK declares it from
// iOS 17 and macOS 14, and the port's package builds against an older one (16.4): the version the SDK gives itself decides, not
// a flag a build has to remember, so the same header compiles against both and against the host's SDK.
#if (TARGET_OS_IPHONE && __IPHONE_OS_VERSION_MAX_ALLOWED < 170000) || (!TARGET_OS_IPHONE && __MAC_OS_X_VERSION_MAX_ALLOWED < 140000)
typedef struct MIDISysexSendRequestUMP MIDISysexSendRequestUMP;
typedef void (*MIDICompletionProcUMP)(MIDISysexSendRequestUMP *request);
struct MIDISysexSendRequestUMP {
    MIDIEndpointRef destination;
    UInt32 *words;
    UInt32 wordsToSend;
    Boolean complete;
    MIDICompletionProcUMP completionProc;
    void *completionRefCon;
};
#endif

// Sends UMP words to a destination of the release as MIDI 1.0 bytes through MIDISendSysex (CharonMIDIPorts.m): 1 when the release
// has the bytes (the request, if one is given, is completed by the release's completion), 0 when nothing was queued.
int CharonMIDIUMPReleaseSend(MIDISysexSendRequestUMP *umpRequest, MIDIEndpointRef dest, const UInt32 *words, UInt32 count);

#endif
