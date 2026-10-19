// MIDIEventPacketSysexBytesForGroup, of iOS 17: the MIDI 1.0 bytes of the SysEx a packet of Universal MIDI Packets holds
// on one group. macOS CoreMIDI was measured for each part of a SysEx, and for the wrong group and a non-SysEx word
// (oracle/sysexbytes.m, sysexbytes-macos.txt, facts/CoreMIDI/Sysex.md): the bytes of a complete message are F0, the data
// and F7; a start is F0 and its data, a continue is its data alone, an end its data and F7; a group other than the
// packet's, or a word that is not SysEx, answers paramErr and no data.
#import <CoreMIDI/CoreMIDI.h>

#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#import "CharonCoreMIDI.h"

OSStatus MIDIEventPacketSysexBytesForGroup(const MIDIEventPacket *pkt, UInt8 groupIndex, CFDataRef *outData)
{
    *outData = NULL;
    if (groupIndex > 15 || pkt->wordCount < 2)
        return charon_paramErr;
    UInt32 first = pkt->words[0];
    if ((first >> 28) != 0x3 || ((first >> 24) & 0x0F) != groupIndex)
        return charon_paramErr;
    // Each two-word SysEx7 part holds at most six data bytes, with at most an F0 before and an F7 after: eight bytes. The parts
    // are counted first, and the room is made for the parts that are there (the loop below stops at the first word that is not
    // one), so a count the packet claims but does not hold asks for nothing, and the product is checked against the size a
    // CFIndex holds (a signed 32 bits on armv7).
    size_t parts = 0;
    for (size_t i = 0; i + 1 < pkt->wordCount; i += 2) {
        UInt32 word = pkt->words[i];
        if ((word >> 28) != 0x3 || ((word >> 24) & 0x0F) != groupIndex)
            break;
        parts++;
    }
    size_t room = 0;
    if (!charon_size_mul(&room, parts, 8) || room > (size_t)LONG_MAX)
        return charon_memFullErr;
    CFIndex capacity = (CFIndex)room;
    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, capacity);
    if (!data)
        return charon_memFullErr;
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

// Sends the words of a UMP request, as macOS does: the words go to the destination unchanged, the request's word count is
// used up, it is marked complete, and its completion procedure is called. A destination this process made gets the words
// verbatim; another destination (the release's, which carries MIDI 1.0 only) gets the SysEx7 messages as MIDI 1.0 bytes, and
// a SysEx8 has no 1.0 form, so it is not sent to one. The answer is noErr whatever the destination, as macOS answers.
static OSStatus charon_send_ump(MIDISysexSendRequestUMP *umpRequest)
{
    if (!umpRequest)
        return charon_paramErr;
    UInt32 count = umpRequest->wordsToSend;
    // The request is used up before anything is queued: once MIDISendSysex has the bytes, the release may complete the
    // send on its own thread, or before the call returns, and the completion may free the request.
    umpRequest->wordsToSend = 0;
    int queued = 0;
    if (count > 0 && umpRequest->words && !CharonMIDIDeliverInProcess(umpRequest->destination, umpRequest->words, count))
        queued = CharonMIDIUMPReleaseSend(umpRequest, umpRequest->destination, umpRequest->words, count);
    // Only a request this call still owns is touched here: a queued one belongs to its completion.
    if (!queued) {
        umpRequest->complete = YES;
        if (umpRequest->completionProc)
            umpRequest->completionProc(umpRequest);
    }
    return noErr;
}

OSStatus MIDISendUMPSysex(MIDISysexSendRequestUMP *umpRequest)
{
    return charon_send_ump(umpRequest);
}

OSStatus MIDISendUMPSysex8(MIDISysexSendRequestUMP *umpRequest)
{
    return charon_send_ump(umpRequest);
}
