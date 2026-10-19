#ifndef CharonCoreMIDI_h
#define CharonCoreMIDI_h

#include <Availability.h>
#include <CoreMIDI/MIDIServices.h>
#include <TargetConditionals.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

enum {
    charon_paramErr = -50,
    charon_memFullErr = -108
};

#define CHARON_PROTOCOL_KEY CFSTR("protocol")

#define CHARON_OWNER_KEY CFSTR("charon.owner")

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

static inline size_t charon_grown_capacity(size_t capacity, size_t element)
{
    size_t next = 0;
    if (capacity > SIZE_MAX / 2 || !charon_size_mul(&next, capacity ? capacity * 2 : 16, element))
        return 0;
    return capacity ? capacity * 2 : 16;
}

typedef struct CharonMIDIWords {
    UInt32 *words;
    size_t count;
    size_t capacity;
    int failed;
    int heap;
} CharonMIDIWords;

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

typedef struct CharonMIDIRPN {
    int selected;
    int nrpn;
    uint8_t msb;
    uint8_t lsb;
} CharonMIDIRPN;

void CharonMIDIWordsAppend(CharonMIDIWords *out, UInt32 word);

void CharonMIDIParseBytes(CharonMIDIParser *parser, const uint8_t *data, size_t length, int protocol,
                          uint8_t group, CharonMIDIWords *out);

void CharonMIDIParseFlush(CharonMIDIParser *parser, uint8_t group, CharonMIDIWords *out);

typedef struct CharonBLEParser {
    int timestampDue;
    int afterTimestamp;
    int inSysex;
    uint8_t running;
    int need;
    int have;
} CharonBLEParser;

size_t CharonBLEMIDIParse(CharonBLEParser *parser, const uint8_t *data, size_t length, uint8_t *out);

void CharonMIDIUMPToBytes(const UInt32 *words, size_t count, CharonMIDIRPN rpn[16], CharonMIDIBytes *out);

int CharonMIDIUMPWordCount(UInt32 word);

UInt32 CharonMIDIUp16From7(UInt32 value);
UInt32 CharonMIDIUp32From7(UInt32 value);
UInt32 CharonMIDIUp32From14(UInt32 value);

MIDIEventPacket *CharonMIDIEventListAdd(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                        MIDITimeStamp time, size_t wordCount, const UInt32 *words);

MIDIEventPacket *CharonMIDIEventListAppend(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                           MIDIEventPacket **last, MIDITimeStamp time, size_t wordCount, const UInt32 *words);

OSStatus CharonMIDIInputPort(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol, MIDIPortRef *outPort,
                             MIDIReceiveBlock receiveBlock);
OSStatus CharonMIDIDestination(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outDest,
                               MIDIReceiveBlock readBlock);
OSStatus CharonMIDISource(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc);
OSStatus CharonMIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist);
OSStatus CharonMIDIReceive(MIDIEndpointRef src, const MIDIEventList *evtlist);
Boolean CharonMIDIDeliverInProcess(MIDIEndpointRef endpoint, const UInt32 *words, UInt32 count);
void CharonMIDIOwnBlock(MIDIObjectRef object, void *retainedBlock);
void CharonMIDIForgetRoute(MIDIObjectRef object);

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

int CharonMIDIUMPReleaseSend(MIDISysexSendRequestUMP *umpRequest, MIDIEndpointRef dest, const UInt32 *words, UInt32 count);

#endif
