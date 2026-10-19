// Charon's translation between MIDI 1.0 bytes and Universal MIDI Packets, and the event list builder's packet
// rules. Nothing here is API: every name begins with Charon, so the library exports none of it, and the files
// that do implement CoreMIDI's functions call it. The rules are measured against macOS CoreMIDI, and the
// reasons, with the measurements, are in facts/CoreMIDI/Translation.md.
#include "CharonCoreMIDI.h"

#include <stdlib.h>
#include <string.h>

void CharonMIDIWordsAppend(CharonMIDIWords *out, UInt32 word)
{
    if (out->failed)
        return;
    if (out->count == out->capacity) {
        size_t capacity = out->capacity ? charon_grown_capacity(out->capacity, sizeof(UInt32)) : 32;
        UInt32 *grown = NULL;
        if (capacity && out->heap) {
            grown = realloc(out->words, capacity * sizeof(UInt32));
        } else if (capacity) {
            // The storage the caller gave is outgrown: the words move to the heap, once.
            grown = malloc(capacity * sizeof(UInt32));
            if (grown && out->count)
                memcpy(grown, out->words, out->count * sizeof(UInt32));
        }
        if (!grown) {
            out->failed = 1;
            return;
        }
        out->words = grown;
        out->capacity = capacity;
        out->heap = 1;
    }
    out->words[out->count++] = word;
}

static void charon_bytes_append(CharonMIDIBytes *out, uint8_t byte)
{
    if (out->failed)
        return;
    if (out->count == out->capacity) {
        size_t capacity = out->capacity ? charon_grown_capacity(out->capacity, 1) : 64;
        uint8_t *grown = NULL;
        if (capacity && out->heap) {
            grown = realloc(out->bytes, capacity);
        } else if (capacity) {
            grown = malloc(capacity);
            if (grown && out->count)
                memcpy(grown, out->bytes, out->count);
        }
        if (!grown) {
            out->failed = 1;
            return;
        }
        out->bytes = grown;
        out->capacity = capacity;
        out->heap = 1;
    }
    out->bytes[out->count++] = byte;
}

// Measured on macOS: a value at or below the centre is shifted up, and a value above it is spread over the
// rest of the range with the slope the measurements give: 65/8 extra per step for 16 bits, a rounded line for
// 32 bits. Each rule matches every value measured (tests/backports/host/coremidi).
UInt32 CharonMIDIUp16From7(UInt32 value)
{
    if (value <= 64)
        return value << 9;
    UInt32 above = value - 64;
    return (value << 9) + 8 * above + (above >> 3);
}

UInt32 CharonMIDIUp32From7(UInt32 value)
{
    if (value <= 64)
        return value << 25;
    // The centre plus above * (2^31 - 1) / 63, rounded as the measurements round it, in 32-bit arithmetic only (a 64-bit
    // divide is a libgcc call on armv7). With above in 1..63, 2 * above * (2^31 - 1) + 63 is above * 126 * 34087042 +
    // 2 * above + 63, because 2^32 = 126 * 34087042 + 4; so the quotient by 126 is above * 34087042 + (2 * above + 63) / 126,
    // where the last term is 0 for above below 32 and 1 from 32. The largest value, above 63, is 0xFFFFFFFF.
    UInt32 above = value - 64; // value is a MIDI data byte, 0 to 127
    return 0x80000000u + above * 34087042u + (2 * above + 63) / 126;
}

UInt32 CharonMIDIUp32From14(UInt32 value)
{
    if (value <= 8192)
        return value << 18;
    UInt32 above = value - 8192;
    return (value << 18) + 32 * above + (above >> 8);
}

// The sizes of the message types, as the macOS visitor reads them (oracle/visit-sizes.m, visit-sizes-macos.txt): types 6 and 7
// are one word, 8 to 0xA two, 0xB and 0xC three, 0xD, 0xE and 0xF four (0xD and 0xF are in visit-expectations.h, which run.sh generates from the recording).
int CharonMIDIUMPWordCount(UInt32 word)
{
    switch (word >> 28) {
    case 0x0: case 0x1: case 0x2: case 0x6: case 0x7:
        return 1;
    case 0x3: case 0x4: case 0x8: case 0x9: case 0xA:
        return 2;
    case 0xB: case 0xC:
        return 3;
    case 0x5: case 0xD: case 0xE: case 0xF:
        return 4;
    }
    return 0;
}

// The system messages a type 1 word carries, as macOS sends them (oracle/ump-invalid-system.m, ump-invalid-system-macos.txt):
// F1, F2, F6, F8 and FE were measured as sent. F3 and F9 to FF are not measured: they follow the same rule. F0 and F7
// are not sent from a system word (a SysEx is type 3), nor are F4 and F5 (undefined), a status below F1, or a channel
// status (a 1.0 message in a system word): measured as not sent for F0, F4, F5, F7, 0x45 and 0x90.
static int charon_system_word(uint8_t status)
{
    return (status >= 0xF1 && status <= 0xF3) || status == 0xF6 || status >= 0xF8;
}

// How many data bytes a channel or system common status carries in MIDI 1.0.
static int charon_data_bytes(uint8_t status)
{
    if (status >= 0x80 && status < 0xF0)
        return (status & 0xE0) == 0xC0 ? 1 : 2;
    switch (status) {
    case 0xF1: case 0xF3:
        return 1;
    case 0xF2:
        return 2;
    }
    return 0;
}

static UInt32 charon_word_channel(UInt32 group, uint8_t status, uint8_t d1, uint8_t d2)
{
    return 0x20000000u | (group << 24) | ((UInt32)status << 16) | ((UInt32)d1 << 8) | d2;
}

static UInt32 charon_word_system(UInt32 group, uint8_t status, uint8_t d1, uint8_t d2)
{
    return 0x10000000u | (group << 24) | ((UInt32)status << 16) | ((UInt32)d1 << 8) | d2;
}

// One complete MIDI 1.0 message, as the protocol asked for it. A 2.0 port gets the channel voice messages as
// their 64-bit form; a note on of velocity 0 stays a 1.0 word, which is what macOS does with it.
static void charon_emit_message(CharonMIDIWords *out, UInt32 group, int protocol, uint8_t status, uint8_t d1, uint8_t d2)
{
    UInt32 channel = status & 0x0F;
    UInt32 kind = status & 0xF0;
    if (status >= 0xF0) {
        CharonMIDIWordsAppend(out, charon_word_system(group, status, d1, d2));
        return;
    }
    if (protocol != 2 || (kind == 0x90 && d2 == 0)) {
        CharonMIDIWordsAppend(out, charon_word_channel(group, status, d1, d2));
        return;
    }
    UInt32 base = group << 24 | channel << 16;
    switch (kind) {
    case 0x80:
        CharonMIDIWordsAppend(out, 0x40800000u | base | (UInt32)d1 << 8);
        CharonMIDIWordsAppend(out, CharonMIDIUp16From7(d2) << 16);
        break;
    case 0x90:
        CharonMIDIWordsAppend(out, 0x40900000u | base | (UInt32)d1 << 8);
        CharonMIDIWordsAppend(out, CharonMIDIUp16From7(d2) << 16);
        break;
    case 0xA0:
        CharonMIDIWordsAppend(out, 0x40A00000u | base | (UInt32)d1 << 8);
        CharonMIDIWordsAppend(out, CharonMIDIUp32From7(d2));
        break;
    case 0xB0:
        CharonMIDIWordsAppend(out, 0x40B00000u | base | (UInt32)d1 << 8);
        CharonMIDIWordsAppend(out, CharonMIDIUp32From7(d2));
        break;
    case 0xC0:
        CharonMIDIWordsAppend(out, 0x40C00000u | base);
        CharonMIDIWordsAppend(out, (UInt32)d1 << 24);
        break;
    case 0xD0:
        CharonMIDIWordsAppend(out, 0x40D00000u | base);
        CharonMIDIWordsAppend(out, CharonMIDIUp32From7(d1));
        break;
    case 0xE0:
        CharonMIDIWordsAppend(out, 0x40E00000u | base);
        CharonMIDIWordsAppend(out, CharonMIDIUp32From14((UInt32)d1 | (UInt32)d2 << 7));
        break;
    }
}

// The bytes of one SysEx chunk, as a UMP SysEx7 packet of one or two words.
static void charon_emit_sysex(CharonMIDIWords *out, UInt32 group, uint8_t status, uint8_t count, const uint8_t *bytes)
{
    uint8_t padded[6] = {0, 0, 0, 0, 0, 0};
    memcpy(padded, bytes, count);
    CharonMIDIWordsAppend(out, 0x30000000u | group << 24 | (UInt32)status << 20 | (UInt32)count << 16 | (UInt32)padded[0] << 8 | padded[1]);
    CharonMIDIWordsAppend(out, (UInt32)padded[2] << 24 | (UInt32)padded[3] << 16 | (UInt32)padded[4] << 8 | padded[5]);
}

// The SysEx chunk the parser holds, sent as a start or a continue when more of the SysEx follows it, or as the
// end or the complete message when the SysEx ends with it.
static void charon_sysex_chunk(CharonMIDIParser *parser, CharonMIDIWords *out, UInt32 group)
{
    charon_emit_sysex(out, group, parser->sysexSent ? 2 : 1, parser->sysexCount, parser->sysex);
    parser->sysexSent = 1;
    parser->sysexCount = 0;
}

// The SysEx ends: what is held goes out as the end, or as the complete message if nothing was sent before it.
static void charon_sysex_finish(CharonMIDIParser *parser, CharonMIDIWords *out, UInt32 group)
{
    charon_emit_sysex(out, group, parser->sysexSent ? 3 : 0, parser->sysexCount, parser->sysex);
    parser->sysexCount = 0;
    parser->sysexSent = 0;
    parser->inSysex = 0;
}

// A byte of a SysEx. The chunk is held until the byte after it arrives, so a SysEx of six bytes is one complete
// message, not a start and an end.
static void charon_sysex_byte(CharonMIDIParser *parser, CharonMIDIWords *out, UInt32 group, uint8_t byte)
{
    if (parser->sysexCount == 6)
        charon_sysex_chunk(parser, out, group);
    parser->sysex[parser->sysexCount++] = byte;
}

// A real-time byte inside a SysEx sends what is held before it. Measured on macOS: with nothing sent before it, that
// is a complete message (status 0), and the SysEx goes on as its end (status 3) after the real-time word; a
// chunk after an earlier one is sent as a continue (status 2), which is not measured and follows the same rule.
static void charon_sysex_realtime(CharonMIDIParser *parser, CharonMIDIWords *out, UInt32 group)
{
    charon_emit_sysex(out, group, parser->sysexSent ? 2 : 0, parser->sysexCount, parser->sysex);
    parser->sysexSent = 1;
    parser->sysexCount = 0;
}

void CharonMIDIParseFlush(CharonMIDIParser *parser, uint8_t group, CharonMIDIWords *out)
{
    if (parser->inSysex && parser->sysexCount > 0)
        charon_sysex_chunk(parser, out, group);
}

void CharonMIDIParseBytes(CharonMIDIParser *parser, const uint8_t *data, size_t length, int protocol,
                          uint8_t group, CharonMIDIWords *out)
{
    UInt32 g = (UInt32)(group & 0x0F);
    for (size_t i = 0; i < length; i++) {
        uint8_t byte = data[i];
        if (byte >= 0xF8) {
            // A real-time message: one word, and it changes neither the running status nor an open SysEx, but
            // the SysEx so far is sent first.
            if (parser->inSysex && parser->sysexCount > 0)
                charon_sysex_realtime(parser, out, g);
            CharonMIDIWordsAppend(out, 0x10000000u | g << 24 | (UInt32)byte << 16);
            continue;
        }
        if (parser->inSysex && byte < 0x80) {
            charon_sysex_byte(parser, out, g, byte);
            continue;
        }
        if (parser->inSysex) {
            // F7 ends the SysEx; any other status cuts it short, and then that status is read as usual.
            charon_sysex_finish(parser, out, g);
            if (byte == 0xF7)
                continue;
        }
        if (byte == 0xF0) {
            parser->inSysex = 1;
            parser->sysexSent = 0;
            parser->sysexCount = 0;
            parser->running = 0;
            parser->pendingNeed = 0;
            continue;
        }
        if (byte == 0xF7) {
            // A stray end of SysEx is not a message.
            continue;
        }
        if (byte >= 0x80) {
            parser->pendingStatus = byte;
            parser->pendingNeed = charon_data_bytes(byte);
            parser->pendingHave = 0;
            if (byte < 0xF0)
                parser->running = byte;
            else
                parser->running = 0;
            if (parser->pendingNeed == 0) {
                charon_emit_message(out, g, protocol, byte, 0, 0);
                parser->pendingNeed = 0;
            }
            continue;
        }
        // A data byte: it belongs to the pending message, or to the running status when none is pending.
        if (parser->pendingNeed == 0) {
            if (parser->running == 0)
                continue;
            parser->pendingStatus = parser->running;
            parser->pendingNeed = charon_data_bytes(parser->running);
            parser->pendingHave = 0;
        }
        parser->pendingData[parser->pendingHave++] = byte;
        if (parser->pendingHave == parser->pendingNeed) {
            uint8_t d1 = parser->pendingData[0];
            uint8_t d2 = parser->pendingNeed > 1 ? parser->pendingData[1] : 0;
            charon_emit_message(out, g, protocol, parser->pendingStatus, d1, d2);
            parser->pendingNeed = 0;
            parser->pendingHave = 0;
        }
    }
}

// The 2.0 parameter selection of a channel, as the 1.0 controllers that make it: RPN is 101 and 100, NRPN is
// 99 and 98, and the data entry is 6 for the most significant part and 38 for the least.
static void charon_select(CharonMIDIBytes *out, CharonMIDIRPN *state, uint8_t channel, int nrpn, uint8_t msb, uint8_t lsb)
{
    if (state->selected && state->nrpn == nrpn && state->msb == msb && state->lsb == lsb)
        return;
    state->selected = 1;
    state->nrpn = nrpn;
    state->msb = msb;
    state->lsb = lsb;
    charon_bytes_append(out, 0xB0 | channel);
    charon_bytes_append(out, nrpn ? 99 : 101);
    charon_bytes_append(out, msb);
    charon_bytes_append(out, 0xB0 | channel);
    charon_bytes_append(out, nrpn ? 98 : 100);
    charon_bytes_append(out, lsb);
}

void CharonMIDIUMPToBytes(const UInt32 *words, size_t count, CharonMIDIRPN rpn[16], CharonMIDIBytes *out)
{
    size_t i = 0;
    while (i < count) {
        UInt32 word = words[i];
        int size = CharonMIDIUMPWordCount(word);
        if (size == 0 || i + (size_t)size > count)
            break;
        UInt32 type = word >> 28;
        if (type == 0x1) {
            uint8_t status = (uint8_t)(word >> 16);
            uint8_t d1 = (uint8_t)(word >> 8), d2 = (uint8_t)word;
            if (charon_system_word(status)) {
                charon_bytes_append(out, status);
                if (charon_data_bytes(status) > 0)
                    charon_bytes_append(out, d1 & 0x7F);
                if (charon_data_bytes(status) > 1)
                    charon_bytes_append(out, d2 & 0x7F);
            }
        } else if (type == 0x2) {
            uint8_t status = (uint8_t)(word >> 16);
            if (status >= 0x80 && status < 0xF0) {
                charon_bytes_append(out, status);
                charon_bytes_append(out, (uint8_t)(word >> 8) & 0x7F);
                if (charon_data_bytes(status) > 1)
                    charon_bytes_append(out, (uint8_t)word & 0x7F);
            }
        } else if (type == 0x3) {
            UInt32 status = (word >> 20) & 0x0F;
            UInt32 n = (word >> 16) & 0x0F;
            uint8_t data[6] = {(uint8_t)(word >> 8), (uint8_t)word, (uint8_t)(words[i + 1] >> 24),
                               (uint8_t)(words[i + 1] >> 16), (uint8_t)(words[i + 1] >> 8), (uint8_t)words[i + 1]};
            if (n > 6)
                n = 6;
            if (status == 0 || status == 1)
                charon_bytes_append(out, 0xF0);
            for (UInt32 k = 0; k < n; k++)
                charon_bytes_append(out, data[k] & 0x7F);
            if (status == 0 || status == 3)
                charon_bytes_append(out, 0xF7);
        } else if (type == 0x4) {
            UInt32 opcode = (word >> 20) & 0x0F;
            uint8_t channel = (uint8_t)((word >> 16) & 0x0F);
            uint8_t index = (uint8_t)(word >> 8);
            UInt32 value = words[i + 1];
            uint8_t v7 = (uint8_t)(value >> 25);
            switch (opcode) {
            case 0x8:
                charon_bytes_append(out, 0x80 | channel);
                charon_bytes_append(out, index & 0x7F);
                charon_bytes_append(out, v7);
                break;
            case 0x9:
                charon_bytes_append(out, 0x90 | channel);
                charon_bytes_append(out, index & 0x7F);
                charon_bytes_append(out, (uint8_t)(v7 ? v7 : 1));
                break;
            case 0xA:
                charon_bytes_append(out, 0xA0 | channel);
                charon_bytes_append(out, index & 0x7F);
                charon_bytes_append(out, v7);
                break;
            case 0xB:
                charon_bytes_append(out, 0xB0 | channel);
                charon_bytes_append(out, index & 0x7F);
                charon_bytes_append(out, v7);
                break;
            case 0xC:
                if (word & 1) {
                    charon_bytes_append(out, 0xB0 | channel);
                    charon_bytes_append(out, 0);
                    charon_bytes_append(out, (uint8_t)(value >> 8) & 0x7F);
                    charon_bytes_append(out, 0xB0 | channel);
                    charon_bytes_append(out, 32);
                    charon_bytes_append(out, (uint8_t)value & 0x7F);
                }
                charon_bytes_append(out, 0xC0 | channel);
                charon_bytes_append(out, (uint8_t)(value >> 24) & 0x7F);
                break;
            case 0xD:
                charon_bytes_append(out, 0xD0 | channel);
                charon_bytes_append(out, v7);
                break;
            case 0xE: {
                uint8_t lsb = (uint8_t)((value >> 18) & 0x7F), msb = (uint8_t)((value >> 25) & 0x7F);
                charon_bytes_append(out, 0xE0 | channel);
                charon_bytes_append(out, lsb);
                charon_bytes_append(out, msb);
                break;
            }
            case 0x2:
            case 0x3: {
                // The registered and the non-registered parameter, both by a bank and an index of 7 bits.
                uint8_t bank = index & 0x7F, number = (uint8_t)word & 0x7F;
                charon_select(out, &rpn[channel], channel, opcode == 0x3, bank, number);
                uint8_t lsb = (uint8_t)((value >> 18) & 0x7F);
                charon_bytes_append(out, 0xB0 | channel);
                charon_bytes_append(out, 6);
                charon_bytes_append(out, v7);
                if (lsb) {
                    charon_bytes_append(out, 0xB0 | channel);
                    charon_bytes_append(out, 38);
                    charon_bytes_append(out, lsb);
                }
                break;
            }
            default:
                // Per-note controllers, per-note pitch bend, per-note management and the relative
                // controllers have no 1.0 form: they produce nothing.
                break;
            }
        }
        i += (size_t)size;
    }
}

// The words of an event packet, which begin after its time stamp and word count.
static UInt32 *charon_packet_words(MIDIEventPacket *packet)
{
    return (UInt32 *)((uint8_t *)packet + sizeof(MIDITimeStamp) + sizeof(UInt32));
}

// Appends the words of one packet to an event list being built, as MIDIEventListAdd does. curPacket is the end of the list's
// content, *last is the list's last packet (NULL when the list is empty), and an event at the time of the last packet is merged
// into it. Returns the new end, or NULL when the words do not fit in listSize bytes. The room is counted down from listSize by
// subtraction, never by adding the words' size to the end: on armv7 that sum wraps for a count of about 2^30 words.
MIDIEventPacket *CharonMIDIEventListAppend(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                           MIDIEventPacket **last, MIDITimeStamp time, size_t wordCount, const UInt32 *words)
{
    uint8_t *base = (uint8_t *)list;
    if (wordCount == 0)
        return curPacket;
    size_t end = (size_t)((uint8_t *)curPacket - base);
    if (end > listSize)
        return NULL;
    size_t room = listSize - end;
    if (list->numPackets > 0 && *last && (*last)->timeStamp == time) {
        // A merge adds four bytes a word, and the packet's word count is a UInt32.
        if (wordCount > room / 4 || wordCount > UINT32_MAX - (*last)->wordCount)
            return NULL;
        memcpy(base + end, words, 4 * wordCount);
        (*last)->wordCount += (UInt32)wordCount;
        return (MIDIEventPacket *)(base + end + 4 * wordCount);
    }
    // A new packet: its time stamp and word count, then the words.
    const size_t header = sizeof(MIDITimeStamp) + sizeof(UInt32);
    if (room < header || wordCount > (room - header) / 4 || wordCount > UINT32_MAX)
        return NULL;
    MIDIEventPacket *packet = (MIDIEventPacket *)(base + end);
    packet->timeStamp = time;
    packet->wordCount = (UInt32)wordCount;
    memcpy(charon_packet_words(packet), words, 4 * wordCount);
    list->numPackets++;
    *last = packet;
    return (MIDIEventPacket *)(base + end + header + 4 * wordCount);
}

// MIDIEventListAdd as macOS keeps it (oracle/eventlistadd-macos.txt): curPacket is the list's last packet (the place MIDIEventListInit
// returned while the list is empty), and the packet written or merged into is returned, so the end is found from curPacket in
// constant time and a list built add by add is linear. NULL when the words do not fit, with the list as it was; for zero words,
// curPacket. A curPacket that is not inside the buffer, or whose word count runs past it, is refused.
MIDIEventPacket *CharonMIDIEventListAdd(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
                                        MIDITimeStamp time, size_t wordCount, const UInt32 *words)
{
    const size_t header = sizeof(MIDITimeStamp) + sizeof(UInt32);
    MIDIEventPacket *last = NULL;
    MIDIEventPacket *end = curPacket;
    if (list->numPackets > 0) {
        uintptr_t base = (uintptr_t)list, at = (uintptr_t)curPacket;
        if (at < base || at - base > listSize || listSize - (at - base) < header)
            return NULL;
        size_t room = listSize - (size_t)(at - base) - header;
        if (curPacket->wordCount > room / 4)
            return NULL;
        last = curPacket;
        end = (MIDIEventPacket *)((uint8_t *)curPacket + header + 4 * (size_t)curPacket->wordCount);
    }
    if (!CharonMIDIEventListAppend(list, listSize, end, &last, time, wordCount, words))
        return NULL;
    return wordCount == 0 ? curPacket : last;
}

// A status byte that is not a timestamp and not real-time: it cuts an open SysEx, and starts the message its data completes.
static void charon_ble_status(CharonBLEParser *parser, uint8_t byte, uint8_t *out, size_t *count)
{
    parser->inSysex = 0;
    parser->need = charon_data_bytes(byte);
    parser->have = 0;
    parser->running = byte < 0xF0 ? byte : 0;
    out[(*count)++] = byte;
    if (parser->need == 0)
        parser->timestampDue = 1;
}

size_t CharonBLEMIDIParse(CharonBLEParser *parser, const uint8_t *data, size_t length, uint8_t *out)
{
    size_t count = 0;
    if (length == 0 || (data[0] & 0x80) == 0)
        return 0;
    parser->timestampDue = 1;
    parser->afterTimestamp = 0;
    for (size_t i = 1; i < length; i++) {
        uint8_t byte = data[i];
        if (byte & 0x80) {
            // Inside a SysEx the framing puts a timestamp before the F7 that ends it and before a real-time byte, so a
            // status-class byte that is not F7 or real-time, and does not follow a timestamp, is that timestamp.
            int sysexTimestamp = parser->inSysex && !parser->afterTimestamp && byte != 0xF7 && byte < 0xF8;
            if (parser->timestampDue || sysexTimestamp) {
                parser->timestampDue = 0;
                parser->afterTimestamp = 1;
                continue;
            }
            parser->afterTimestamp = 0;
            if (byte >= 0xF8) {
                // Real-time: one message of its own, sent inside a SysEx as well, and it neither changes the running
                // status nor closes the SysEx. Outside a SysEx the next message has its own timestamp.
                out[count++] = byte;
                if (!parser->inSysex)
                    parser->timestampDue = 1;
            } else if (byte == 0xF0) {
                parser->inSysex = 1;
                parser->running = 0;
                parser->need = 0;
                out[count++] = byte;
            } else if (byte == 0xF7) {
                // The end of an open SysEx; a stray F7 is not a message.
                if (parser->inSysex) {
                    out[count++] = byte;
                    parser->inSysex = 0;
                    parser->timestampDue = 1;
                }
            } else {
                charon_ble_status(parser, byte, out, &count);
            }
            continue;
        }
        parser->afterTimestamp = 0;
        if (parser->inSysex) {
            out[count++] = byte;
            continue;
        }
        if (parser->need == 0) {
            // Running status: a data byte after a timestamp, with the last channel status to carry it. Without one it is dropped.
            if (parser->running == 0)
                continue;
            parser->need = charon_data_bytes(parser->running);
            parser->have = 0;
            out[count++] = parser->running;
        }
        out[count++] = byte;
        if (++parser->have == parser->need) {
            parser->need = 0;
            parser->have = 0;
            parser->timestampDue = 1;
        }
    }
    return count;
}
