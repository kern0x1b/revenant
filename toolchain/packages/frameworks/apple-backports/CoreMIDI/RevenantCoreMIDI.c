#include "RevenantCoreMIDI.h"

#include <stdlib.h>
#include <string.h>

void RevenantMIDIWordsAppend(RevenantMIDIWords *out, UInt32 word)
{
    if (out->failed)
        return;
    if (out->count == out->capacity) {
        size_t capacity = out->capacity ? revenant_grown_capacity(out->capacity, sizeof(UInt32)) : 32;
        UInt32 *grown = NULL;
        if (capacity && out->heap) {
            grown = realloc(out->words, capacity * sizeof(UInt32));
        } else if (capacity) {
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

static void revenant_bytes_append(RevenantMIDIBytes *out, uint8_t byte)
{
    if (out->failed)
        return;
    if (out->count == out->capacity) {
        size_t capacity = out->capacity ? revenant_grown_capacity(out->capacity, 1) : 64;
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

UInt32 RevenantMIDIUp16From7(UInt32 value)
{
    if (value <= 64)
        return value << 9;
    UInt32 above = value - 64;
    return (value << 9) + 8 * above + (above >> 3);
}

UInt32 RevenantMIDIUp32From7(UInt32 value)
{
    if (value <= 64)
        return value << 25;
    UInt32 above = value - 64;
    return 0x80000000u + above * 34087042u + (2 * above + 63) / 126;
}

UInt32 RevenantMIDIUp32From14(UInt32 value)
{
    if (value <= 8192)
        return value << 18;
    UInt32 above = value - 8192;
    return (value << 18) + 32 * above + (above >> 8);
}

int RevenantMIDIUMPWordCount(UInt32 word)
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

static int revenant_system_word(uint8_t status)
{
    return (status >= 0xF1 && status <= 0xF3) || status == 0xF6 || status >= 0xF8;
}

static int revenant_data_bytes(uint8_t status)
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

static UInt32 revenant_word_channel(UInt32 group, uint8_t status, uint8_t d1, uint8_t d2)
{
    return 0x20000000u | (group << 24) | ((UInt32)status << 16) | ((UInt32)d1 << 8) | d2;
}

static UInt32 revenant_word_system(UInt32 group, uint8_t status, uint8_t d1, uint8_t d2)
{
    return 0x10000000u | (group << 24) | ((UInt32)status << 16) | ((UInt32)d1 << 8) | d2;
}

static void revenant_emit_message(RevenantMIDIWords *out, UInt32 group, int protocol, uint8_t status, uint8_t d1, uint8_t d2)
{
    UInt32 channel = status & 0x0F;
    UInt32 kind = status & 0xF0;
    if (status >= 0xF0) {
        RevenantMIDIWordsAppend(out, revenant_word_system(group, status, d1, d2));
        return;
    }
    if (protocol != 2 || (kind == 0x90 && d2 == 0)) {
        RevenantMIDIWordsAppend(out, revenant_word_channel(group, status, d1, d2));
        return;
    }
    UInt32 base = group << 24 | channel << 16;
    switch (kind) {
    case 0x80:
        RevenantMIDIWordsAppend(out, 0x40800000u | base | (UInt32)d1 << 8);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp16From7(d2) << 16);
        break;
    case 0x90:
        RevenantMIDIWordsAppend(out, 0x40900000u | base | (UInt32)d1 << 8);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp16From7(d2) << 16);
        break;
    case 0xA0:
        RevenantMIDIWordsAppend(out, 0x40A00000u | base | (UInt32)d1 << 8);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp32From7(d2));
        break;
    case 0xB0:
        RevenantMIDIWordsAppend(out, 0x40B00000u | base | (UInt32)d1 << 8);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp32From7(d2));
        break;
    case 0xC0:
        RevenantMIDIWordsAppend(out, 0x40C00000u | base);
        RevenantMIDIWordsAppend(out, (UInt32)d1 << 24);
        break;
    case 0xD0:
        RevenantMIDIWordsAppend(out, 0x40D00000u | base);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp32From7(d1));
        break;
    case 0xE0:
        RevenantMIDIWordsAppend(out, 0x40E00000u | base);
        RevenantMIDIWordsAppend(out, RevenantMIDIUp32From14((UInt32)d1 | (UInt32)d2 << 7));
        break;
    }
}

static void revenant_emit_sysex(RevenantMIDIWords *out, UInt32 group, uint8_t status, uint8_t count, const uint8_t *bytes)
{
    uint8_t padded[6] = {0, 0, 0, 0, 0, 0};
    memcpy(padded, bytes, count);
    RevenantMIDIWordsAppend(out, 0x30000000u | group << 24 | (UInt32)status << 20 | (UInt32)count << 16 | (UInt32)padded[0] << 8 | padded[1]);
    RevenantMIDIWordsAppend(out, (UInt32)padded[2] << 24 | (UInt32)padded[3] << 16 | (UInt32)padded[4] << 8 | padded[5]);
}

static void revenant_sysex_chunk(RevenantMIDIParser *parser, RevenantMIDIWords *out, UInt32 group)
{
    revenant_emit_sysex(out, group, parser->sysexSent ? 2 : 1, parser->sysexCount, parser->sysex);
    parser->sysexSent = 1;
    parser->sysexCount = 0;
}

static void revenant_sysex_finish(RevenantMIDIParser *parser, RevenantMIDIWords *out, UInt32 group)
{
    revenant_emit_sysex(out, group, parser->sysexSent ? 3 : 0, parser->sysexCount, parser->sysex);
    parser->sysexCount = 0;
    parser->sysexSent = 0;
    parser->inSysex = 0;
}

static void revenant_sysex_byte(RevenantMIDIParser *parser, RevenantMIDIWords *out, UInt32 group, uint8_t byte)
{
    if (parser->sysexCount == 6)
        revenant_sysex_chunk(parser, out, group);
    parser->sysex[parser->sysexCount++] = byte;
}

static void revenant_sysex_realtime(RevenantMIDIParser *parser, RevenantMIDIWords *out, UInt32 group)
{
    revenant_emit_sysex(out, group, parser->sysexSent ? 2 : 0, parser->sysexCount, parser->sysex);
    parser->sysexSent = 1;
    parser->sysexCount = 0;
}

void RevenantMIDIParseFlush(RevenantMIDIParser *parser, uint8_t group, RevenantMIDIWords *out)
{
    if (parser->inSysex && parser->sysexCount > 0)
        revenant_sysex_chunk(parser, out, group);
}

void RevenantMIDIParseBytes(RevenantMIDIParser *parser, const uint8_t *data, size_t length, int protocol,
                          uint8_t group, RevenantMIDIWords *out)
{
    UInt32 g = (UInt32)(group & 0x0F);
    for (size_t i = 0; i < length; i++) {
        uint8_t byte = data[i];
        if (byte >= 0xF8) {
            if (parser->inSysex && parser->sysexCount > 0)
                revenant_sysex_realtime(parser, out, g);
            RevenantMIDIWordsAppend(out, 0x10000000u | g << 24 | (UInt32)byte << 16);
            continue;
        }
        if (parser->inSysex && byte < 0x80) {
            revenant_sysex_byte(parser, out, g, byte);
            continue;
        }
        if (parser->inSysex) {
            revenant_sysex_finish(parser, out, g);
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
            continue;
        }
        if (byte >= 0x80) {
            parser->pendingStatus = byte;
            parser->pendingNeed = revenant_data_bytes(byte);
            parser->pendingHave = 0;
            if (byte < 0xF0)
                parser->running = byte;
            else
                parser->running = 0;
            if (parser->pendingNeed == 0) {
                revenant_emit_message(out, g, protocol, byte, 0, 0);
                parser->pendingNeed = 0;
            }
            continue;
        }
        if (parser->pendingNeed == 0) {
            if (parser->running == 0)
                continue;
            parser->pendingStatus = parser->running;
            parser->pendingNeed = revenant_data_bytes(parser->running);
            parser->pendingHave = 0;
        }
        parser->pendingData[parser->pendingHave++] = byte;
        if (parser->pendingHave == parser->pendingNeed) {
            uint8_t d1 = parser->pendingData[0];
            uint8_t d2 = parser->pendingNeed > 1 ? parser->pendingData[1] : 0;
            revenant_emit_message(out, g, protocol, parser->pendingStatus, d1, d2);
            parser->pendingNeed = 0;
            parser->pendingHave = 0;
        }
    }
}

static void revenant_select(RevenantMIDIBytes *out, RevenantMIDIRPN *state, uint8_t channel, int nrpn, uint8_t msb, uint8_t lsb)
{
    if (state->selected && state->nrpn == nrpn && state->msb == msb && state->lsb == lsb)
        return;
    state->selected = 1;
    state->nrpn = nrpn;
    state->msb = msb;
    state->lsb = lsb;
    revenant_bytes_append(out, 0xB0 | channel);
    revenant_bytes_append(out, nrpn ? 99 : 101);
    revenant_bytes_append(out, msb);
    revenant_bytes_append(out, 0xB0 | channel);
    revenant_bytes_append(out, nrpn ? 98 : 100);
    revenant_bytes_append(out, lsb);
}

void RevenantMIDIUMPToBytes(const UInt32 *words, size_t count, RevenantMIDIRPN rpn[16], RevenantMIDIBytes *out)
{
    size_t i = 0;
    while (i < count) {
        UInt32 word = words[i];
        int size = RevenantMIDIUMPWordCount(word);
        if (size == 0 || i + (size_t)size > count)
            break;
        UInt32 type = word >> 28;
        if (type == 0x1) {
            uint8_t status = (uint8_t)(word >> 16);
            uint8_t d1 = (uint8_t)(word >> 8), d2 = (uint8_t)word;
            if (revenant_system_word(status)) {
                revenant_bytes_append(out, status);
                if (revenant_data_bytes(status) > 0)
                    revenant_bytes_append(out, d1 & 0x7F);
                if (revenant_data_bytes(status) > 1)
                    revenant_bytes_append(out, d2 & 0x7F);
            }
        } else if (type == 0x2) {
            uint8_t status = (uint8_t)(word >> 16);
            if (status >= 0x80 && status < 0xF0) {
                revenant_bytes_append(out, status);
                revenant_bytes_append(out, (uint8_t)(word >> 8) & 0x7F);
                if (revenant_data_bytes(status) > 1)
                    revenant_bytes_append(out, (uint8_t)word & 0x7F);
            }
        } else if (type == 0x3) {
            UInt32 status = (word >> 20) & 0x0F;
            UInt32 n = (word >> 16) & 0x0F;
            uint8_t data[6] = {(uint8_t)(word >> 8), (uint8_t)word, (uint8_t)(words[i + 1] >> 24),
                               (uint8_t)(words[i + 1] >> 16), (uint8_t)(words[i + 1] >> 8), (uint8_t)words[i + 1]};
            if (n > 6)
                n = 6;
            if (status == 0 || status == 1)
                revenant_bytes_append(out, 0xF0);
            for (UInt32 k = 0; k < n; k++)
                revenant_bytes_append(out, data[k] & 0x7F);
            if (status == 0 || status == 3)
                revenant_bytes_append(out, 0xF7);
        } else if (type == 0x4) {
            UInt32 opcode = (word >> 20) & 0x0F;
            uint8_t channel = (uint8_t)((word >> 16) & 0x0F);
            uint8_t index = (uint8_t)(word >> 8);
            UInt32 value = words[i + 1];
            uint8_t v7 = (uint8_t)(value >> 25);
            switch (opcode) {
            case 0x8:
                revenant_bytes_append(out, 0x80 | channel);
                revenant_bytes_append(out, index & 0x7F);
                revenant_bytes_append(out, v7);
                break;
            case 0x9:
                revenant_bytes_append(out, 0x90 | channel);
                revenant_bytes_append(out, index & 0x7F);
                revenant_bytes_append(out, (uint8_t)(v7 ? v7 : 1));
                break;
            case 0xA:
                revenant_bytes_append(out, 0xA0 | channel);
                revenant_bytes_append(out, index & 0x7F);
                revenant_bytes_append(out, v7);
                break;
            case 0xB:
                revenant_bytes_append(out, 0xB0 | channel);
                revenant_bytes_append(out, index & 0x7F);
                revenant_bytes_append(out, v7);
                break;
            case 0xC:
                if (word & 1) {
                    revenant_bytes_append(out, 0xB0 | channel);
                    revenant_bytes_append(out, 0);
                    revenant_bytes_append(out, (uint8_t)(value >> 8) & 0x7F);
                    revenant_bytes_append(out, 0xB0 | channel);
                    revenant_bytes_append(out, 32);
                    revenant_bytes_append(out, (uint8_t)value & 0x7F);
                }
                revenant_bytes_append(out, 0xC0 | channel);
                revenant_bytes_append(out, (uint8_t)(value >> 24) & 0x7F);
                break;
            case 0xD:
                revenant_bytes_append(out, 0xD0 | channel);
                revenant_bytes_append(out, v7);
                break;
            case 0xE: {
                uint8_t lsb = (uint8_t)((value >> 18) & 0x7F), msb = (uint8_t)((value >> 25) & 0x7F);
                revenant_bytes_append(out, 0xE0 | channel);
                revenant_bytes_append(out, lsb);
                revenant_bytes_append(out, msb);
                break;
            }
            case 0x2:
            case 0x3: {
                uint8_t bank = index & 0x7F, number = (uint8_t)word & 0x7F;
                revenant_select(out, &rpn[channel], channel, opcode == 0x3, bank, number);
                uint8_t lsb = (uint8_t)((value >> 18) & 0x7F);
                revenant_bytes_append(out, 0xB0 | channel);
                revenant_bytes_append(out, 6);
                revenant_bytes_append(out, v7);
                if (lsb) {
                    revenant_bytes_append(out, 0xB0 | channel);
                    revenant_bytes_append(out, 38);
                    revenant_bytes_append(out, lsb);
                }
                break;
            }
            default:
                break;
            }
        }
        i += (size_t)size;
    }
}

static UInt32 *revenant_packet_words(MIDIEventPacket *packet)
{
    return (UInt32 *)((uint8_t *)packet + sizeof(MIDITimeStamp) + sizeof(UInt32));
}

MIDIEventPacket *RevenantMIDIEventListAppend(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
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
        if (wordCount > room / 4 || wordCount > UINT32_MAX - (*last)->wordCount)
            return NULL;
        memcpy(base + end, words, 4 * wordCount);
        (*last)->wordCount += (UInt32)wordCount;
        return (MIDIEventPacket *)(base + end + 4 * wordCount);
    }
    const size_t header = sizeof(MIDITimeStamp) + sizeof(UInt32);
    if (room < header || wordCount > (room - header) / 4 || wordCount > UINT32_MAX)
        return NULL;
    MIDIEventPacket *packet = (MIDIEventPacket *)(base + end);
    packet->timeStamp = time;
    packet->wordCount = (UInt32)wordCount;
    memcpy(revenant_packet_words(packet), words, 4 * wordCount);
    list->numPackets++;
    *last = packet;
    return (MIDIEventPacket *)(base + end + header + 4 * wordCount);
}

MIDIEventPacket *RevenantMIDIEventListAdd(MIDIEventList *list, size_t listSize, MIDIEventPacket *curPacket,
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
    if (!RevenantMIDIEventListAppend(list, listSize, end, &last, time, wordCount, words))
        return NULL;
    return wordCount == 0 ? curPacket : last;
}

static void revenant_ble_status(RevenantBLEParser *parser, uint8_t byte, uint8_t *out, size_t *count)
{
    parser->inSysex = 0;
    parser->need = revenant_data_bytes(byte);
    parser->have = 0;
    parser->running = byte < 0xF0 ? byte : 0;
    out[(*count)++] = byte;
    if (parser->need == 0)
        parser->timestampDue = 1;
}

size_t RevenantBLEMIDIParse(RevenantBLEParser *parser, const uint8_t *data, size_t length, uint8_t *out)
{
    size_t count = 0;
    if (length == 0 || (data[0] & 0x80) == 0)
        return 0;
    parser->timestampDue = 1;
    parser->afterTimestamp = 0;
    for (size_t i = 1; i < length; i++) {
        uint8_t byte = data[i];
        if (byte & 0x80) {
            int sysexTimestamp = parser->inSysex && !parser->afterTimestamp && byte != 0xF7 && byte < 0xF8;
            if (parser->timestampDue || sysexTimestamp) {
                parser->timestampDue = 0;
                parser->afterTimestamp = 1;
                continue;
            }
            parser->afterTimestamp = 0;
            if (byte >= 0xF8) {
                out[count++] = byte;
                if (!parser->inSysex)
                    parser->timestampDue = 1;
            } else if (byte == 0xF0) {
                parser->inSysex = 1;
                parser->running = 0;
                parser->need = 0;
                out[count++] = byte;
            } else if (byte == 0xF7) {
                if (parser->inSysex) {
                    out[count++] = byte;
                    parser->inSysex = 0;
                    parser->timestampDue = 1;
                }
            } else {
                revenant_ble_status(parser, byte, out, &count);
            }
            continue;
        }
        parser->afterTimestamp = 0;
        if (parser->inSysex) {
            out[count++] = byte;
            continue;
        }
        if (parser->need == 0) {
            if (parser->running == 0)
                continue;
            parser->need = revenant_data_bytes(parser->running);
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
