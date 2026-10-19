// MIDIEventListForEachEvent, of iOS 15: the parser that hands a visitor each Universal MIDI Packet of an event list as
// a MIDIUniversalMessage. The release has no event list, so the list is this library's own (MIDIEventList14.m), and the
// visitor parses it here.
//
// The fields are the header's, with what macOS CoreMIDI was measured to hand the visitor where the header is silent
// (oracle/visit.m, oracle/visit-jr.txt, facts/CoreMIDI/Visitor.md): a utility message has no group and gets 0xFF, its
// jitter clock is the low byte of the word's 16-bit field, a real-time message and every word of a type the header does
// not name arrive as type 0xFF with the raw words, and a SysEx8 stream's data is copied from byte 3 of the first word.
#import <CoreMIDI/CoreMIDI.h>

#import "CharonCoreMIDI.h"

#include <stdio.h>
#include <string.h>

// The type a message gets when the visitor cannot name it: the release's own unknown value.
static const UInt32 charon_unknown_type = 0xFF;

static void charon_fill_unknown(MIDIUniversalMessage *message, UInt32 group, const UInt32 *words, int count)
{
    message->type = (MIDIMessageType)charon_unknown_type;
    message->group = (UInt8)group;
    for (int i = 0; i < 4; i++)
        message->unknown.words[i] = i < count ? words[i] : 0;
}

// A UMP of one word or more, parsed into the message the visitor is handed. words points at the first word and the
// message is words[0...size-1].
static void charon_parse(const UInt32 *words, int size, MIDIUniversalMessage *message)
{
    memset(message, 0, sizeof(*message));
    UInt32 first = words[0];
    UInt32 type = first >> 28;
    UInt32 group = (first >> 24) & 0x0F;
    switch (type) {
    case 0x0: {
        UInt32 status = (first >> 20) & 0x0F;
        if (status == 0 || status > 2) {
            charon_fill_unknown(message, 0xFF, words, size);
            return;
        }
        message->type = (MIDIMessageType)kMIDIMessageTypeUtility;
        message->group = 0xFF;
        message->utility.status = (MIDIUtilityStatus)status;
        message->utility.jitterReductionClock = (UInt16)(first & 0xFF);
        return;
    }
    case 0x1: {
        UInt32 status = (first >> 16) & 0xFF;
        UInt32 d1 = (first >> 8) & 0xFF, d2 = first & 0xFF;
        if (status >= 0xF8) {
            charon_fill_unknown(message, group, words, size);
            return;
        }
        message->type = (MIDIMessageType)kMIDIMessageTypeSystem;
        message->group = (UInt8)group;
        message->system.status = (MIDISystemStatus)status;
        if (status == 0xF2)
            message->system.songPositionPointer = (UInt16)(d1 | (d2 << 7));
        else
            message->system.timeCode = (UInt8)d1;
        return;
    }
    case 0x2: {
        message->type = (MIDIMessageType)kMIDIMessageTypeChannelVoice1;
        message->group = (UInt8)group;
        message->channelVoice1.status = (MIDICVStatus)((first >> 20) & 0x0F);
        message->channelVoice1.channel = (UInt8)((first >> 16) & 0x0F);
        message->channelVoice1.note.number = (UInt8)((first >> 8) & 0xFF);
        message->channelVoice1.note.velocity = (UInt8)(first & 0xFF);
        if (message->channelVoice1.status == kMIDICVStatusPitchBend)
            message->channelVoice1.pitchBend = (UInt16)(((first >> 8) & 0x7F) | ((first & 0x7F) << 7));
        return;
    }
    case 0x3: {
        message->type = (MIDIMessageType)kMIDIMessageTypeSysEx;
        message->group = (UInt8)group;
        message->sysEx.status = (MIDISysExStatus)((first >> 20) & 0x0F);
        message->sysEx.channel = (UInt8)((first >> 16) & 0x0F);
        UInt8 bytes[6] = {(UInt8)(first >> 8), (UInt8)first, (UInt8)(words[1] >> 24), (UInt8)(words[1] >> 16),
                          (UInt8)(words[1] >> 8), (UInt8)words[1]};
        memcpy(message->sysEx.data, bytes, 6);
        return;
    }
    case 0x4: {
        message->type = (MIDIMessageType)kMIDIMessageTypeChannelVoice2;
        message->group = (UInt8)group;
        UInt32 opcode = (first >> 20) & 0x0F;
        UInt32 channel = (first >> 16) & 0x0F;
        UInt8 index = (UInt8)(first >> 8);
        UInt32 value = words[1];
        message->channelVoice2.status = (MIDICVStatus)opcode;
        message->channelVoice2.channel = (UInt8)channel;
        switch (opcode) {
        case 0x8: case 0x9:
            message->channelVoice2.note.number = index;
            message->channelVoice2.note.attributeType = (MIDINoteAttribute)(first & 0xFF);
            message->channelVoice2.note.velocity = (UInt16)(value >> 16);
            message->channelVoice2.note.attribute = (UInt16)value;
            break;
        case 0xA:
            message->channelVoice2.polyPressure.noteNumber = index;
            message->channelVoice2.polyPressure.pressure = value;
            break;
        case 0xB:
            message->channelVoice2.controlChange.index = index;
            message->channelVoice2.controlChange.data = value;
            break;
        case 0xC:
            message->channelVoice2.programChange.options = (MIDIProgramChangeOptions)(first & 0x01);
            message->channelVoice2.programChange.program = (UInt8)(value >> 24);
            message->channelVoice2.programChange.bank = (UInt16)((((value >> 8) & 0x7F) << 7) | (value & 0x7F));
            break;
        case 0xD:
            message->channelVoice2.channelPressure.data = value;
            break;
        case 0xE:
            message->channelVoice2.pitchBend.data = value;
            break;
        case 0x6:
            message->channelVoice2.perNotePitchBend.noteNumber = index;
            message->channelVoice2.perNotePitchBend.bend = value;
            break;
        case 0x0: case 0x1:
            message->channelVoice2.perNoteController.noteNumber = index;
            message->channelVoice2.perNoteController.index = (UInt8)(first & 0xFF);
            message->channelVoice2.perNoteController.data = value;
            break;
        case 0x2: case 0x3: case 0x4: case 0x5:
            message->channelVoice2.controller.bank = index;
            message->channelVoice2.controller.index = (UInt8)(first & 0xFF);
            message->channelVoice2.controller.data = value;
            break;
        case 0xF:
            message->channelVoice2.perNoteManagement.note = index;
            message->channelVoice2.perNoteManagement.options = (MIDIPerNoteManagementOptions)(first & 0xFF);
            break;
        }
        return;
    }
    case 0x5: {
        // A SysEx8 stream: measured, the data is the bytes of the words from byte 3 of the first word.
        message->type = (MIDIMessageType)kMIDIMessageTypeData128;
        message->group = (UInt8)group;
        message->data128.status = (MIDISysExStatus)((first >> 20) & 0x0F);
        message->data128.sysex8.byteCount = (UInt8)((first >> 16) & 0x0F);
        message->data128.sysex8.streamID = (UInt8)(first >> 8);
        UInt8 raw[16];
        for (int w = 0; w < 4; w++) {
            UInt32 word = w < size ? words[w] : 0;
            raw[4 * w] = (UInt8)word;
            raw[4 * w + 1] = (UInt8)(word >> 8);
            raw[4 * w + 2] = (UInt8)(word >> 16);
            raw[4 * w + 3] = (UInt8)(word >> 24);
        }
        memcpy(message->data128.sysex8.data, raw + 3, 13);
        return;
    }
    default:
        charon_fill_unknown(message, 0xFF, words, size);
        return;
    }
}

void MIDIEventListForEachEvent(const MIDIEventList *evtlist, MIDIEventVisitor visitor, void *visitorContext)
{
    const MIDIEventPacket *packet = &evtlist->packet[0];
    for (UInt32 i = 0; i < evtlist->numPackets; i++) {
        UInt32 index = 0;
        while (index < packet->wordCount) {
            int size = CharonMIDIUMPWordCount(packet->words[index]);
            if (size == 0 || index + (UInt32)size > packet->wordCount)
                break;
            MIDIUniversalMessage message;
            charon_parse(&packet->words[index], size, &message);
            visitor(visitorContext, packet->timeStamp, message);
            index += (UInt32)size;
        }
        packet = MIDIEventPacketNext(packet);
    }
}
