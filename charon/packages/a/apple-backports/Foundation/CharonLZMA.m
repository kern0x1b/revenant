#import <Foundation/Foundation.h>
#include <string.h>

typedef struct {
    uint16_t choice;
    uint16_t choice2;
    uint16_t low[16][8];
    uint16_t mid[16][8];
    uint16_t high[256];
} CharonLengthModel;

typedef struct {
    uint16_t match[12][16];
    uint16_t rep[12];
    uint16_t repG0[12];
    uint16_t repG1[12];
    uint16_t repG2[12];
    uint16_t rep0Long[12][16];
    uint16_t slot[4][64];
    uint16_t special[114];
    uint16_t align[16];
    CharonLengthModel length;
    CharonLengthModel repLength;
    uint16_t *literal;
    unsigned lc, lp, pb;
} CharonLZMAModel;

static void charon_lzma_reset(CharonLZMAModel *model, unsigned lc, unsigned lp, unsigned pb)
{
    uint16_t *literal = model->literal;
    NSUInteger count = 0x300u << (lc + lp);
    if (!literal)
        literal = malloc(count * sizeof(uint16_t));
    memset(model, 0, sizeof(*model));
    model->literal = literal;
    model->lc = lc;
    model->lp = lp;
    model->pb = pb;
    uint16_t *probs = (uint16_t *)model;
    NSUInteger tableCount = (offsetof(CharonLZMAModel, literal)) / sizeof(uint16_t);
    for (NSUInteger index = 0; index < tableCount; index++)
        probs[index] = 1024;
    for (NSUInteger index = 0; index < count; index++)
        literal[index] = 1024;
}

typedef struct {
    uint64_t low;
    uint32_t range;
    uint8_t cache;
    uint64_t cacheSize;
    NSMutableData *out;
} CharonRangeEncoder;

static void charon_rc_shift(CharonRangeEncoder *rc)
{
    if ((uint32_t)rc->low < 0xFF000000u || (rc->low >> 32) != 0) {
        uint8_t carry = (uint8_t)(rc->low >> 32);
        uint8_t byte = rc->cache;
        do {
            uint8_t value = (uint8_t)(byte + carry);
            [rc->out appendBytes:&value length:1];
            byte = 0xFF;
        } while (--rc->cacheSize != 0);
        rc->cache = (uint8_t)(rc->low >> 24);
    }
    rc->cacheSize++;
    rc->low = (rc->low & 0x00FFFFFFu) << 8;
}

static void charon_rc_bit(CharonRangeEncoder *rc, uint16_t *probability, int bit)
{
    uint32_t bound = (rc->range >> 11) * *probability;
    if (!bit) {
        rc->range = bound;
        *probability += (2048 - *probability) >> 5;
    } else {
        rc->low += bound;
        rc->range -= bound;
        *probability -= *probability >> 5;
    }
    while (rc->range < (1u << 24)) {
        rc->range <<= 8;
        charon_rc_shift(rc);
    }
}

static void charon_rc_direct(CharonRangeEncoder *rc, uint32_t value, int bits)
{
    for (int index = bits - 1; index >= 0; index--) {
        rc->range >>= 1;
        if ((value >> index) & 1)
            rc->low += rc->range;
        while (rc->range < (1u << 24)) {
            rc->range <<= 8;
            charon_rc_shift(rc);
        }
    }
}

static void charon_rc_tree(CharonRangeEncoder *rc, uint16_t *probabilities, int bits, uint32_t symbol)
{
    uint32_t node = 1;
    for (int index = bits - 1; index >= 0; index--) {
        int bit = (symbol >> index) & 1;
        charon_rc_bit(rc, &probabilities[node], bit);
        node = (node << 1) | (uint32_t)bit;
    }
}

static void charon_rc_tree_reverse(CharonRangeEncoder *rc, uint16_t *probabilities, int bits, uint32_t symbol)
{
    uint32_t node = 1;
    for (int index = 0; index < bits; index++) {
        int bit = symbol & 1;
        symbol >>= 1;
        charon_rc_bit(rc, &probabilities[node], bit);
        node = (node << 1) | (uint32_t)bit;
    }
}

static void charon_rc_length(CharonRangeEncoder *rc, CharonLengthModel *model, uint32_t length, unsigned posState)
{
    if (length < 8) {
        charon_rc_bit(rc, &model->choice, 0);
        charon_rc_tree(rc, model->low[posState], 3, length);
    } else if (length < 16) {
        charon_rc_bit(rc, &model->choice, 1);
        charon_rc_bit(rc, &model->choice2, 0);
        charon_rc_tree(rc, model->mid[posState], 3, length - 8);
    } else {
        charon_rc_bit(rc, &model->choice, 1);
        charon_rc_bit(rc, &model->choice2, 1);
        charon_rc_tree(rc, model->high, 8, length - 16);
    }
}

static const NSUInteger charon_lzma_chunk = 32768;
static const NSUInteger charon_lzma_window = 16u * 1024 * 1024;

typedef struct {
    const unsigned char *bytes;
    NSUInteger length;
    int32_t *head;
    int32_t *previous;
} CharonMatchFinder;

static uint32_t charon_lzma_hash(const unsigned char *at)
{
    return (((uint32_t)at[0] | ((uint32_t)at[1] << 8) | ((uint32_t)at[2] << 16)) * 2654435761u) >> 16;
}

static void charon_lzma_insert(CharonMatchFinder *finder, NSUInteger position)
{
    if (position + 3 > finder->length)
        return;
    uint32_t slot = charon_lzma_hash(finder->bytes + position);
    finder->previous[position] = finder->head[slot];
    finder->head[slot] = (int32_t)position;
}

static NSUInteger charon_lzma_find(CharonMatchFinder *finder, NSUInteger position, NSUInteger *distance)
{
    if (position + 3 > finder->length)
        return 0;
    NSUInteger best = 0;
    NSUInteger limit = MIN((NSUInteger)273, finder->length - position);
    int32_t candidate = finder->head[charon_lzma_hash(finder->bytes + position)];
    for (int depth = 0; depth < 24 && candidate >= 0; depth++) {
        NSUInteger away = position - (NSUInteger)candidate;
        if (away > charon_lzma_window)
            break;
        NSUInteger size = 0;
        while (size < limit && finder->bytes[candidate + size] == finder->bytes[position + size])
            size++;
        if (size > best && (size >= 4 || away < 4096)) {
            best = size;
            *distance = away;
            if (size == limit)
                break;
        }
        candidate = finder->previous[candidate];
    }
    return best >= 3 ? best : 0;
}

static NSData *charon_lzma_encode_chunk(CharonLZMAModel *model, CharonMatchFinder *finder, NSUInteger start, NSUInteger end, unsigned *state, NSUInteger *lastDistance)
{
    NSMutableData *out = [NSMutableData data];
    CharonRangeEncoder rc = {0, 0xFFFFFFFFu, 0, 1, out};
    NSUInteger position = start;
    while (position < end) {
        unsigned posState = position & ((1u << model->pb) - 1);
        NSUInteger distance = 0;
        NSUInteger length = charon_lzma_find(finder, position, &distance);
        if (position + length > end)
            length = end - position;
        if (length < 3)
            length = 0;
        if (length) {
            charon_rc_bit(&rc, &model->match[*state][posState], 1);
            charon_rc_bit(&rc, &model->rep[*state], 0);
            charon_rc_length(&rc, &model->length, (uint32_t)(length - 2), posState);
            uint32_t reduced = (uint32_t)(distance - 1);
            uint32_t lengthState = length - 2 < 4 ? (uint32_t)(length - 2) : 3;
            uint32_t slot;
            if (reduced < 4) {
                slot = reduced;
            } else {
                int top = 31 - __builtin_clz(reduced);
                slot = (uint32_t)(2 * top) + ((reduced >> (top - 1)) & 1);
            }
            charon_rc_tree(&rc, model->slot[lengthState], 6, slot);
            if (slot >= 4) {
                int footer = (int)(slot >> 1) - 1;
                uint32_t base = (2 | (slot & 1)) << footer;
                uint32_t rest = reduced - base;
                if (slot < 14) {
                    charon_rc_tree_reverse(&rc, model->special + base - slot - 1, footer, rest);
                } else {
                    charon_rc_direct(&rc, rest >> 4, footer - 4);
                    charon_rc_tree_reverse(&rc, model->align, 4, rest & 15);
                }
            }
            *state = *state < 7 ? 7 : 10;
            *lastDistance = distance;
            for (NSUInteger index = 0; index < length; index++)
                charon_lzma_insert(finder, position + index);
            position += length;
        } else {
            charon_rc_bit(&rc, &model->match[*state][posState], 0);
            unsigned char previous = position ? finder->bytes[position - 1] : 0;
            unsigned literalState = (unsigned)(((position & ((1u << model->lp) - 1)) << model->lc) + (previous >> (8 - model->lc)));
            uint16_t *probabilities = model->literal + 0x300 * literalState;
            uint32_t symbol = finder->bytes[position];
            if (*state < 7) {
                charon_rc_tree(&rc, probabilities, 8, symbol);
            } else {
                uint32_t matchByte = finder->bytes[position - *lastDistance];
                uint32_t offset = 0x100;
                uint32_t coded = symbol | 0x100;
                do {
                    matchByte <<= 1;
                    charon_rc_bit(&rc, &probabilities[offset + (matchByte & offset) + (coded >> 8)], (coded >> 7) & 1);
                    coded <<= 1;
                    offset &= ~(matchByte ^ coded);
                } while (coded < 0x10000);
            }
            *state = *state < 4 ? 0 : (*state < 10 ? *state - 3 : *state - 6);
            charon_lzma_insert(finder, position);
            position++;
        }
    }
    for (int index = 0; index < 5; index++)
        charon_rc_shift(&rc);
    return out;
}

static uint32_t charon_crc32(const unsigned char *bytes, NSUInteger length)
{
    static uint32_t table[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (uint32_t index = 0; index < 256; index++) {
            uint32_t value = index;
            for (int bit = 0; bit < 8; bit++)
                value = (value & 1) ? (value >> 1) ^ 0xEDB88320u : value >> 1;
            table[index] = value;
        }
    });
    uint32_t crc = 0xFFFFFFFFu;
    for (NSUInteger index = 0; index < length; index++)
        crc = table[(crc ^ bytes[index]) & 0xFF] ^ (crc >> 8);
    return ~crc;
}

static void charon_put_le32(NSMutableData *data, uint32_t value)
{
    unsigned char bytes[4] = {value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF};
    [data appendBytes:bytes length:4];
}

static void charon_put_varint(NSMutableData *data, uint64_t value)
{
    do {
        unsigned char byte = value & 0x7F;
        value >>= 7;
        if (value)
            byte |= 0x80;
        [data appendBytes:&byte length:1];
    } while (value);
}

NSData *charon_lzma_compress(NSData *input);
NSData *charon_lzma_decompress(NSData *input);

NSData *charon_lzma_compress(NSData *input)
{
    NSMutableData *out = [NSMutableData data];
    const unsigned char header[8] = {0xFD, '7', 'z', 'X', 'Z', 0x00, 0x00, 0x00};
    [out appendBytes:header length:8];
    charon_put_le32(out, charon_crc32(header + 6, 2));
    NSUInteger length = input.length;
    NSMutableData *body = [NSMutableData data];
    if (length) {
        const unsigned char *bytes = input.bytes;
        CharonMatchFinder finder = {bytes, length, malloc(65536 * sizeof(int32_t)), malloc(length * sizeof(int32_t))};
        memset(finder.head, 0xFF, 65536 * sizeof(int32_t));
        CharonLZMAModel model;
        memset(&model, 0, sizeof(model));
        unsigned state = 0;
        NSUInteger lastDistance = 1;
        BOOL dictionaryReset = NO;
        BOOL propertiesSent = NO;
        for (NSUInteger start = 0; start < length; start += charon_lzma_chunk) {
            NSUInteger end = MIN(length, start + charon_lzma_chunk);
            charon_lzma_reset(&model, 3, 0, 2);
            state = 0;
            NSData *packed = charon_lzma_encode_chunk(&model, &finder, start, end, &state, &lastDistance);
            NSUInteger size = end - start;
            if (packed.length < size) {
                unsigned control = !dictionaryReset ? 0xE0 : (!propertiesSent ? 0xC0 : 0xA0);
                control |= (unsigned)((size - 1) >> 16);
                unsigned char chunk[5] = {(unsigned char)control, (unsigned char)((size - 1) >> 8), (unsigned char)(size - 1), (unsigned char)((packed.length - 1) >> 8), (unsigned char)(packed.length - 1)};
                [body appendBytes:chunk length:5];
                if (!propertiesSent) {
                    unsigned char properties = (unsigned char)((2 * 5 + 0) * 9 + 3);
                    [body appendBytes:&properties length:1];
                }
                [body appendData:packed];
                dictionaryReset = propertiesSent = YES;
            } else {
                unsigned char chunk[3] = {dictionaryReset ? 0x02 : 0x01, (unsigned char)((size - 1) >> 8), (unsigned char)(size - 1)};
                [body appendBytes:chunk length:3];
                [body appendBytes:bytes + start length:size];
                dictionaryReset = YES;
                propertiesSent = propertiesSent && NO;
            }
        }
        free(finder.head);
        free(finder.previous);
        free(model.literal);
        unsigned char end = 0;
        [body appendBytes:&end length:1];
        const unsigned char blockHeader[8] = {0x02, 0x00, 0x21, 0x01, 0x18, 0x00, 0x00, 0x00};
        NSMutableData *block = [NSMutableData dataWithBytes:blockHeader length:8];
        charon_put_le32(block, charon_crc32(blockHeader, 8));
        [block appendData:body];
        NSUInteger unpadded = block.length;
        while (block.length % 4)
            [block appendBytes:"\0" length:1];
        [out appendData:block];
        NSMutableData *index = [NSMutableData data];
        unsigned char indicator = 0;
        [index appendBytes:&indicator length:1];
        charon_put_varint(index, 1);
        charon_put_varint(index, unpadded);
        charon_put_varint(index, length);
        while ((index.length + 4) % 4)
            [index appendBytes:"\0" length:1];
        charon_put_le32(index, charon_crc32(index.bytes, index.length));
        [out appendData:index];
        NSMutableData *footer = [NSMutableData data];
        charon_put_le32(footer, (uint32_t)(index.length / 4 - 1));
        const unsigned char flags[2] = {0, 0};
        [footer appendBytes:flags length:2];
        NSMutableData *checked = [NSMutableData dataWithData:footer];
        charon_put_le32(out, charon_crc32(checked.bytes, checked.length));
        [out appendData:footer];
        [out appendBytes:"YZ" length:2];
        return out;
    }
    unsigned char indexBytes[8] = {0x00, 0x00, 0x00, 0x00};
    NSMutableData *index = [NSMutableData dataWithBytes:indexBytes length:4];
    charon_put_le32(index, charon_crc32(index.bytes, index.length));
    [out appendData:index];
    NSMutableData *footer = [NSMutableData data];
    charon_put_le32(footer, (uint32_t)(index.length / 4 - 1));
    const unsigned char flags[2] = {0, 0};
    [footer appendBytes:flags length:2];
    charon_put_le32(out, charon_crc32(footer.bytes, footer.length));
    [out appendData:footer];
    [out appendBytes:"YZ" length:2];
    return out;
}

typedef struct {
    const unsigned char *bytes;
    NSUInteger length;
    NSUInteger at;
    uint32_t range;
    uint32_t code;
    BOOL failed;
} CharonRangeDecoder;

static void charon_rd_normalize(CharonRangeDecoder *rd)
{
    if (rd->range < (1u << 24)) {
        rd->range <<= 8;
        if (rd->at >= rd->length) {
            rd->failed = YES;
            return;
        }
        rd->code = (rd->code << 8) | rd->bytes[rd->at++];
    }
}

static int charon_rd_bit(CharonRangeDecoder *rd, uint16_t *probability)
{
    uint32_t bound = (rd->range >> 11) * *probability;
    int bit;
    if (rd->code < bound) {
        rd->range = bound;
        *probability += (2048 - *probability) >> 5;
        bit = 0;
    } else {
        rd->code -= bound;
        rd->range -= bound;
        *probability -= *probability >> 5;
        bit = 1;
    }
    charon_rd_normalize(rd);
    return bit;
}

static uint32_t charon_rd_direct(CharonRangeDecoder *rd, int bits)
{
    uint32_t result = 0;
    while (bits--) {
        rd->range >>= 1;
        int bit = 0;
        if (rd->code >= rd->range) {
            rd->code -= rd->range;
            bit = 1;
        }
        result = (result << 1) | (uint32_t)bit;
        charon_rd_normalize(rd);
    }
    return result;
}

static uint32_t charon_rd_tree(CharonRangeDecoder *rd, uint16_t *probabilities, int bits)
{
    uint32_t node = 1;
    for (int index = 0; index < bits; index++)
        node = (node << 1) | (uint32_t)charon_rd_bit(rd, &probabilities[node]);
    return node - (1u << bits);
}

static uint32_t charon_rd_tree_reverse(CharonRangeDecoder *rd, uint16_t *probabilities, int bits)
{
    uint32_t node = 1;
    uint32_t result = 0;
    for (int index = 0; index < bits; index++) {
        int bit = charon_rd_bit(rd, &probabilities[node]);
        node = (node << 1) | (uint32_t)bit;
        result |= (uint32_t)bit << index;
    }
    return result;
}

static uint32_t charon_rd_length(CharonRangeDecoder *rd, CharonLengthModel *model, unsigned posState)
{
    if (!charon_rd_bit(rd, &model->choice))
        return charon_rd_tree(rd, model->low[posState], 3);
    if (!charon_rd_bit(rd, &model->choice2))
        return 8 + charon_rd_tree(rd, model->mid[posState], 3);
    return 16 + charon_rd_tree(rd, model->high, 8);
}

static BOOL charon_lzma_decode_chunk(CharonLZMAModel *model, const unsigned char *packed, NSUInteger packedLength, unsigned char *out, NSUInteger position, NSUInteger size, NSUInteger dictionaryStart, unsigned *state, uint32_t reps[4])
{
    if (packedLength < 5 || packed[0] != 0)
        return NO;
    CharonRangeDecoder rd = {packed, packedLength, 5, 0xFFFFFFFFu, ((uint32_t)packed[1] << 24) | ((uint32_t)packed[2] << 16) | ((uint32_t)packed[3] << 8) | packed[4], NO};
    NSUInteger end = position + size;
    unsigned s = *state;
    while (position < end) {
        unsigned posState = position & ((1u << model->pb) - 1);
        if (!charon_rd_bit(&rd, &model->match[s][posState])) {
            unsigned char previous = position > dictionaryStart ? out[position - 1] : 0;
            unsigned literalState = (unsigned)(((position & ((1u << model->lp) - 1)) << model->lc) + (previous >> (8 - model->lc)));
            uint16_t *probabilities = model->literal + 0x300 * literalState;
            uint32_t symbol = 1;
            if (s >= 7) {
                if (reps[0] + 1 > position - dictionaryStart)
                    return NO;
                uint32_t matchByte = out[position - reps[0] - 1];
                uint32_t offset = 0x100;
                do {
                    matchByte <<= 1;
                    uint32_t bit = matchByte & offset;
                    int decoded = charon_rd_bit(&rd, &probabilities[offset + bit + symbol]);
                    symbol = (symbol << 1) | (uint32_t)decoded;
                    offset &= decoded ? bit : ~bit;
                } while (symbol < 0x100);
            } else {
                do {
                    symbol = (symbol << 1) | (uint32_t)charon_rd_bit(&rd, &probabilities[symbol]);
                } while (symbol < 0x100);
            }
            out[position++] = (unsigned char)symbol;
            s = s < 4 ? 0 : (s < 10 ? s - 3 : s - 6);
        } else {
            uint32_t length;
            if (charon_rd_bit(&rd, &model->rep[s])) {
                if (position == dictionaryStart)
                    return NO;
                if (!charon_rd_bit(&rd, &model->repG0[s])) {
                    if (!charon_rd_bit(&rd, &model->rep0Long[s][posState])) {
                        if (reps[0] + 1 > position - dictionaryStart)
                            return NO;
                        out[position] = out[position - reps[0] - 1];
                        position++;
                        s = s < 7 ? 9 : 11;
                        continue;
                    }
                } else {
                    uint32_t distance;
                    if (!charon_rd_bit(&rd, &model->repG1[s])) {
                        distance = reps[1];
                    } else {
                        if (!charon_rd_bit(&rd, &model->repG2[s])) {
                            distance = reps[2];
                        } else {
                            distance = reps[3];
                            reps[3] = reps[2];
                        }
                        reps[2] = reps[1];
                    }
                    reps[1] = reps[0];
                    reps[0] = distance;
                }
                length = charon_rd_length(&rd, &model->repLength, posState);
                s = s < 7 ? 8 : 11;
            } else {
                reps[3] = reps[2];
                reps[2] = reps[1];
                reps[1] = reps[0];
                length = charon_rd_length(&rd, &model->length, posState);
                s = s < 7 ? 7 : 10;
                uint32_t lengthState = length < 4 ? length : 3;
                uint32_t slot = charon_rd_tree(&rd, model->slot[lengthState], 6);
                uint32_t distance = slot;
                if (slot >= 4) {
                    int footer = (int)(slot >> 1) - 1;
                    distance = (2 | (slot & 1)) << footer;
                    if (slot < 14) {
                        distance += charon_rd_tree_reverse(&rd, model->special + distance - slot - 1, footer);
                    } else {
                        distance += charon_rd_direct(&rd, footer - 4) << 4;
                        distance += charon_rd_tree_reverse(&rd, model->align, 4);
                    }
                }
                if (distance == 0xFFFFFFFFu)
                    return NO;
                reps[0] = distance;
            }
            length += 2;
            if (reps[0] + 1 > position - dictionaryStart || length > end - position)
                return NO;
            for (uint32_t index = 0; index < length; index++, position++)
                out[position] = out[position - reps[0] - 1];
        }
        if (rd.failed)
            return NO;
    }
    *state = s;
    return !rd.failed && rd.at == packedLength && rd.code == 0;
}

static BOOL charon_read_varint(const unsigned char *bytes, NSUInteger length, NSUInteger *at, uint64_t *value)
{
    *value = 0;
    for (int shift = 0; shift < 63; shift += 7) {
        if (*at >= length)
            return NO;
        unsigned char byte = bytes[(*at)++];
        *value |= (uint64_t)(byte & 0x7F) << shift;
        if (!(byte & 0x80))
            return YES;
    }
    return NO;
}

NSData *charon_lzma_decompress(NSData *input)
{
    const unsigned char *bytes = input.bytes;
    NSUInteger length = input.length;
    if (length < 32 || memcmp(bytes, "\xFD" "7zXZ\0", 6) != 0 || bytes[6] != 0 || (bytes[7] & 0xF0) != 0)
        return nil;
    if (charon_crc32(bytes + 6, 2) != ((uint32_t)bytes[8] | ((uint32_t)bytes[9] << 8) | ((uint32_t)bytes[10] << 16) | ((uint32_t)bytes[11] << 24)))
        return nil;
    unsigned check = bytes[7] & 0x0F;
    NSUInteger checkSize = check == 0 ? 0 : (check == 1 ? 4 : (check == 4 ? 8 : (check == 10 ? 32 : NSNotFound)));
    if (checkSize == NSNotFound)
        return nil;
    NSMutableData *out = [NSMutableData data];
    NSUInteger at = 12;
    CharonLZMAModel model;
    memset(&model, 0, sizeof(model));
    BOOL ok = YES;
    NSUInteger records = 0;
    while (ok) {
        if (at >= length) {
            ok = NO;
            break;
        }
        if (bytes[at] == 0)
            break;
        NSUInteger headerSize = ((NSUInteger)bytes[at] + 1) * 4;
        if (at + headerSize > length || headerSize < 12) {
            ok = NO;
            break;
        }
        if (charon_crc32(bytes + at, headerSize - 4) != ((uint32_t)bytes[at + headerSize - 4] | ((uint32_t)bytes[at + headerSize - 3] << 8) | ((uint32_t)bytes[at + headerSize - 2] << 16) | ((uint32_t)bytes[at + headerSize - 1] << 24))) {
            ok = NO;
            break;
        }
        NSUInteger cursor = at + 2;
        unsigned flags = bytes[at + 1];
        uint64_t skipped;
        if ((flags & 0x03) != 0 || (flags & 0x3C) != 0) {
            ok = NO;
            break;
        }
        if (flags & 0x40)
            ok = charon_read_varint(bytes, at + headerSize - 4, &cursor, &skipped);
        if (ok && (flags & 0x80))
            ok = charon_read_varint(bytes, at + headerSize - 4, &cursor, &skipped);
        uint64_t filter, propertySize;
        ok = ok && charon_read_varint(bytes, at + headerSize - 4, &cursor, &filter) && filter == 0x21 &&
             charon_read_varint(bytes, at + headerSize - 4, &cursor, &propertySize) && propertySize == 1 && cursor < at + headerSize - 4 && bytes[cursor] <= 40;
        if (!ok)
            break;
        NSUInteger blockStart = at;
        at += headerSize;
        NSUInteger dictionaryStart = out.length;
        unsigned state = 0;
        uint32_t reps[4] = {0, 0, 0, 0};
        BOOL haveProperties = NO;
        BOOL dictionaryReady = NO;
        for (;;) {
            if (at >= length) {
                ok = NO;
                break;
            }
            unsigned control = bytes[at++];
            if (control == 0)
                break;
            if (control == 1 || control == 2) {
                if (at + 2 > length) {
                    ok = NO;
                    break;
                }
                NSUInteger size = (((NSUInteger)bytes[at] << 8) | bytes[at + 1]) + 1;
                at += 2;
                if (control == 1) {
                    dictionaryStart = out.length;
                    dictionaryReady = YES;
                } else if (!dictionaryReady) {
                    ok = NO;
                    break;
                }
                if (at + size > length) {
                    ok = NO;
                    break;
                }
                [out appendBytes:bytes + at length:size];
                at += size;
                continue;
            }
            if (control < 0x80 || at + 4 > length) {
                ok = NO;
                break;
            }
            NSUInteger size = (((NSUInteger)(control & 0x1F) << 16) | ((NSUInteger)bytes[at] << 8) | bytes[at + 1]) + 1;
            NSUInteger packedSize = (((NSUInteger)bytes[at + 2] << 8) | bytes[at + 3]) + 1;
            at += 4;
            unsigned mode = (control >> 5) & 3;
            if (mode == 3) {
                dictionaryStart = out.length;
                dictionaryReady = YES;
            }
            if (!dictionaryReady) {
                ok = NO;
                break;
            }
            if (mode >= 2) {
                if (at >= length) {
                    ok = NO;
                    break;
                }
                unsigned properties = bytes[at++];
                if (properties >= 225) {
                    ok = NO;
                    break;
                }
                unsigned lc = properties % 9, lp = (properties / 9) % 5, pb = properties / 45;
                if (lc + lp > 4) {
                    ok = NO;
                    break;
                }
                free(model.literal);
                model.literal = NULL;
                charon_lzma_reset(&model, lc, lp, pb);
                haveProperties = YES;
                state = 0;
                memset(reps, 0, sizeof(reps));
            } else if (mode == 1) {
                if (!haveProperties) {
                    ok = NO;
                    break;
                }
                charon_lzma_reset(&model, model.lc, model.lp, model.pb);
                state = 0;
                memset(reps, 0, sizeof(reps));
            }
            if (!haveProperties || at + packedSize > length || out.length + size > 0x7FFFFFFFu) {
                ok = NO;
                break;
            }
            NSUInteger position = out.length;
            out.length = position + size;
            ok = charon_lzma_decode_chunk(&model, bytes + at, packedSize, out.mutableBytes, position, size, dictionaryStart, &state, reps);
            at += packedSize;
            if (!ok)
                break;
        }
        if (!ok)
            break;
        while ((at - blockStart) % 4) {
            if (at >= length || bytes[at]) {
                ok = NO;
                break;
            }
            at++;
        }
        if (!ok)
            break;
        if (at + checkSize > length) {
            ok = NO;
            break;
        }
        at += checkSize;
        records++;
    }
    free(model.literal);
    if (!ok)
        return nil;
    if (at + 1 > length || bytes[at] != 0)
        return nil;
    NSUInteger indexStart = at++;
    uint64_t count;
    if (!charon_read_varint(bytes, length, &at, &count) || count != records)
        return nil;
    uint64_t totalUnpacked = 0;
    for (uint64_t index = 0; index < count; index++) {
        uint64_t unpadded, unpacked;
        if (!charon_read_varint(bytes, length, &at, &unpadded) || !charon_read_varint(bytes, length, &at, &unpacked))
            return nil;
        totalUnpacked += unpacked;
    }
    if (totalUnpacked != out.length)
        return nil;
    while ((at - indexStart) % 4) {
        if (at >= length || bytes[at])
            return nil;
        at++;
    }
    if (at + 4 + 12 != length)
        return nil;
    uint32_t indexCRC = (uint32_t)bytes[at] | ((uint32_t)bytes[at + 1] << 8) | ((uint32_t)bytes[at + 2] << 16) | ((uint32_t)bytes[at + 3] << 24);
    if (charon_crc32(bytes + indexStart, at - indexStart) != indexCRC)
        return nil;
    at += 4;
    uint32_t footerCRC = (uint32_t)bytes[at] | ((uint32_t)bytes[at + 1] << 8) | ((uint32_t)bytes[at + 2] << 16) | ((uint32_t)bytes[at + 3] << 24);
    uint32_t backward = (uint32_t)bytes[at + 4] | ((uint32_t)bytes[at + 5] << 8) | ((uint32_t)bytes[at + 6] << 16) | ((uint32_t)bytes[at + 7] << 24);
    if (charon_crc32(bytes + at + 4, 6) != footerCRC || memcmp(bytes + at + 8, bytes + 6, 2) != 0 || memcmp(bytes + at + 10, "YZ", 2) != 0 ||
        ((NSUInteger)backward + 1) * 4 != at - indexStart)
        return nil;
    return out;
}
