#import <CoreMIDI/CoreMIDI.h>

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#import "RevenantCoreMIDI.h"

OSStatus MIDIEventPacketSysexBytesForGroup(const MIDIEventPacket *pkt, UInt8 groupIndex, CFDataRef *outData)
{
    *outData = NULL;
    if (groupIndex > 15 || pkt->wordCount < 2)
        return revenant_paramErr;
    UInt32 first = pkt->words[0];
    if ((first >> 28) != 0x3 || ((first >> 24) & 0x0F) != groupIndex)
        return revenant_paramErr;
    size_t parts = 0;
    for (size_t i = 0; i + 1 < pkt->wordCount; i += 2) {
        UInt32 word = pkt->words[i];
        if ((word >> 28) != 0x3 || ((word >> 24) & 0x0F) != groupIndex)
            break;
        parts++;
    }
    size_t room = 0;
    if (!revenant_size_mul(&room, parts, 8) || room > (size_t)LONG_MAX)
        return revenant_memFullErr;
    CFIndex capacity = (CFIndex)room;
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, capacity);
    if (!data)
        return revenant_memFullErr;
    CFDataSetLength(data, capacity);
    UInt8 *bytes = CFDataGetMutableBytePtr(data);
    CFIndex count = 0;
    for (UInt32 i = 0; i + 1 < pkt->wordCount; i += 2) {
        UInt32 word = pkt->words[i];
        if ((word >> 28) != 0x3 || ((word >> 24) & 0x0F) != groupIndex)
            break;
        UInt32 status = (word >> 20) & 0x0F;
        UInt32 n = (word >> 16) & 0x0F;
        UInt32 second = pkt->words[i + 1];
        UInt8 part[6] = {(UInt8)(word >> 8), (UInt8)word, (UInt8)(second >> 24), (UInt8)(second >> 16),
                         (UInt8)(second >> 8), (UInt8)second};
        if (n > 6)
            n = 6;
        if (status == 0x0 || status == 0x1)
            bytes[count++] = 0xF0;
        for (UInt32 k = 0; k < n; k++)
            bytes[count++] = part[k] & 0x7F;
        if (status == 0x0 || status == 0x3)
            bytes[count++] = 0xF7;
    }
    CFDataSetLength(data, count);
    *outData = data;
    return noErr;
}

static OSStatus revenant_send_ump(MIDISysexSendRequestUMP *umpRequest)
{
    if (!umpRequest)
        return revenant_paramErr;
    UInt32 count = umpRequest->wordsToSend;
    umpRequest->wordsToSend = 0;
    int queued = 0;
    if (count > 0 && umpRequest->words && !RevenantMIDIDeliverInProcess(umpRequest->destination, umpRequest->words, count))
        queued = RevenantMIDIUMPReleaseSend(umpRequest, umpRequest->destination, umpRequest->words, count);
    if (!queued) {
        umpRequest->complete = YES;
        if (umpRequest->completionProc)
            umpRequest->completionProc(umpRequest);
    }
    return noErr;
}

OSStatus MIDISendUMPSysex(MIDISysexSendRequestUMP *umpRequest)
{
    return revenant_send_ump(umpRequest);
}

OSStatus MIDISendUMPSysex8(MIDISysexSendRequestUMP *umpRequest)
{
    return revenant_send_ump(umpRequest);
}
