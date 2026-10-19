#ifndef RevenantCoreMIDI_h
#define RevenantCoreMIDI_h

#include <Availability.h>
#include <CoreMIDI/MIDIServices.h>
#include <TargetConditionals.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

enum {
    revenant_paramErr = -50,
    revenant_memFullErr = -108
};

#define REVENANT_PROTOCOL_KEY CFSTR("protocol")

#define REVENANT_OWNER_KEY CFSTR("revenant.owner")

static inline int revenant_size_add(size_t *sum, size_t value)
{
    if (value > SIZE_MAX - *sum)
        return 0;
    *sum += value;
    return 1;
}

static inline int revenant_size_mul(size_t *product, size_t count, size_t each)
{
    if (each != 0 && count > SIZE_MAX / each)
        return 0;
    *product = count * each;
    return 1;
}

static inline size_t revenant_grown_capacity(size_t capacity, size_t element)
{
    size_t next = 0;
    if (capacity > SIZE_MAX / 2 || !revenant_size_mul(&next, capacity ? capacity * 2 : 16, element))
        return 0;
    return capacity ? capacity * 2 : 16;
}

typedef struct RevenantMIDIWords {
    UInt32 *words;
    size_t count;
    size_t capacity;
    int failed;
    int heap;
} RevenantMIDIWords;

typedef struct RevenantMIDIBytes {
    uint8_t *bytes;
    size_t count;
    size_t capacity;
    int failed;
    int heap;
} RevenantMIDIBytes;

static inline void RevenantMIDIWordsUseStorage(RevenantMIDIWords *out, UInt32 *storage, size_t capacity)
{
    out->words = storage;
    out->count = 0;
    out->capacity = capacity;
    out->failed = 0;
    out->heap = 0;
}

static inline void RevenantMIDIWordsRelease(RevenantMIDIWords *out)
{
    if (out->heap)
        free(out->words);
    out->words = NULL;
    out->heap = 0;
    out->capacity = 0;
}

static inline void RevenantMIDIBytesUseStorage(RevenantMIDIBytes *out, uint8_t *storage, size_t capacity)
{
    out->bytes = storage;
    out->count = 0;
    out->capacity = capacity;
    out->failed = 0;
    out->heap = 0;
}

static inline void RevenantMIDIBytesRelease(RevenantMIDIBytes *out)
{
    if (out->heap)
        free(out->bytes);
    out->bytes = NULL;
    out->heap = 0;
    out->capacity = 0;
}

typedef struct RevenantMIDIParser {
    uint8_t running;
    uint8_t pendingStatus;
    int pendingNeed;
    int pendingHave;
    uint8_t pendingData[2];
    int inSysex;
    int sysexSent;
    uint8_t sysexCount;
    uint8_t sysex[6];
} RevenantMIDIParser;

typedef struct RevenantMIDIRPN {
    int selected;
    int nrpn;
    uint8_t msb;
    uint8_t lsb;
} RevenantMIDIRPN;

void RevenantMIDIWordsAppend(RevenantMIDIWords *out, UInt32 word);

void RevenantMIDIParseBytes(RevenantMIDIParser *parser, const uint8_t *data, size_t length, int protocol,
                          uint8_t group, RevenantMIDIWords *out);

void RevenantMIDIParseFlush(RevenantMIDIParser *parser, uint8_t group, RevenantMIDIWords *out);

typedef struct RevenantBLEParser {
    int timestampDue;
    int afterTimestamp;
    int inSysex;
    uint8_t running;
    int need;
    int have;
} RevenantBLEParser;

size_t RevenantBLEMIDIParse(RevenantBLEParser *parser, const uint8_t *data, size_t length, uint8_t *out);

void RevenantMIDIUMPToBytes(const UInt32 *words, size_t count, RevenantMIDIRPN rpn[16], RevenantMIDIBytes *out);

int RevenantMIDIUMPWordCount(UInt32 word);

UInt32 RevenantMIDIUp16From7(UInt32 value);
UInt32 RevenantMIDIUp32From7(UInt32 value);
UInt32 RevenantMIDIUp32From14(UInt32 value);

MIDIEventPacket *RevenantMIDIEventListAdd(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                        MIDITimeStamp time, size_t wordCount, const UInt32 *words);

MIDIEventPacket *RevenantMIDIEventListAppend(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                           MIDIEventPacket **last, MIDITimeStamp time, size_t wordCount, const UInt32 *words);

OSStatus RevenantMIDIInputPort(MIDIClientRef client, CFStringRef portName, MIDIProtocolID protocol, MIDIPortRef *outPort,
                             MIDIReceiveBlock receiveBlock);
OSStatus RevenantMIDIDestination(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outDest,
                               MIDIReceiveBlock readBlock);
OSStatus RevenantMIDISource(MIDIClientRef client, CFStringRef name, MIDIProtocolID protocol, MIDIEndpointRef *outSrc);
OSStatus RevenantMIDISend(MIDIPortRef port, MIDIEndpointRef dest, const MIDIEventList *evtlist);
OSStatus RevenantMIDIReceive(MIDIEndpointRef src, const MIDIEventList *evtlist);
Boolean RevenantMIDIDeliverInProcess(MIDIEndpointRef endpoint, const UInt32 *words, UInt32 count);
void RevenantMIDIOwnBlock(MIDIObjectRef object, void *retainedBlock);
void RevenantMIDIForgetRoute(MIDIObjectRef object);

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

int RevenantMIDIUMPReleaseSend(MIDISysexSendRequestUMP *umpRequest, MIDIEndpointRef dest, const UInt32 *words, UInt32 count);

#endif
