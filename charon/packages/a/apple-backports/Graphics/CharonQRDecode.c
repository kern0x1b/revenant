#include "CharonQRDecode.h"

#include <string.h>

#define CHARON_QR_MAX_BLOCKS 81
#define CHARON_QR_MAX_BLOCK 150
#define CHARON_QR_MAX_CODEWORDS 3706
#define CHARON_QR_MAX_SIZE 177

typedef struct {
    uint8_t exp[512];
    uint8_t log[256];
} charon_qr_gf;

typedef struct {
    uint8_t ec;
    uint8_t b1;
    uint8_t d1;
    uint8_t b2;
    uint8_t d2;
} charon_qr_blocks;

typedef struct {
    const uint8_t *bytes;
    size_t bits;
    size_t pos;
} charon_qr_reader;

static const charon_qr_blocks kBlocks[41][4] = {
    {{0}},
    {{7,1,19,0,0}, {10,1,16,0,0}, {13,1,13,0,0}, {17,1,9,0,0}},
    {{10,1,34,0,0}, {16,1,28,0,0}, {22,1,22,0,0}, {28,1,16,0,0}},
    {{15,1,55,0,0}, {26,1,44,0,0}, {18,2,17,0,0}, {22,2,13,0,0}},
    {{20,1,80,0,0}, {18,2,32,0,0}, {26,2,24,0,0}, {16,4,9,0,0}},
    {{26,1,108,0,0}, {24,2,43,0,0}, {18,2,15,2,16}, {22,2,11,2,12}},
    {{18,2,68,0,0}, {16,4,27,0,0}, {24,4,19,0,0}, {28,4,15,0,0}},
    {{20,2,78,0,0}, {18,4,31,0,0}, {18,2,14,4,15}, {26,4,13,1,14}},
    {{24,2,97,0,0}, {22,2,38,2,39}, {22,4,18,2,19}, {26,4,14,2,15}},
    {{30,2,116,0,0}, {22,3,36,2,37}, {20,4,16,4,17}, {24,4,12,4,13}},
    {{18,2,68,2,69}, {26,4,43,1,44}, {24,6,19,2,20}, {28,6,15,2,16}},
    {{20,4,81,0,0}, {30,1,50,4,51}, {28,4,22,4,23}, {24,3,12,8,13}},
    {{24,2,92,2,93}, {22,6,36,2,37}, {26,4,20,6,21}, {28,7,14,4,15}},
    {{26,4,107,0,0}, {22,8,37,1,38}, {24,8,20,4,21}, {22,12,11,4,12}},
    {{30,3,115,1,116}, {24,4,40,5,41}, {20,11,16,5,17}, {24,11,12,5,13}},
    {{22,5,87,1,88}, {24,5,41,5,42}, {30,5,24,7,25}, {24,11,12,7,13}},
    {{24,5,98,1,99}, {28,7,45,3,46}, {24,15,19,2,20}, {30,3,15,13,16}},
    {{28,1,107,5,108}, {28,10,46,1,47}, {28,1,22,15,23}, {28,2,14,17,15}},
    {{30,5,120,1,121}, {26,9,43,4,44}, {28,17,22,1,23}, {28,2,14,19,15}},
    {{28,3,113,4,114}, {26,3,44,11,45}, {26,17,21,4,22}, {26,9,13,16,14}},
    {{28,3,107,5,108}, {26,3,41,13,42}, {30,15,24,5,25}, {28,15,15,10,16}},
    {{28,4,116,4,117}, {26,17,42,0,0}, {28,17,22,6,23}, {30,19,16,6,17}},
    {{28,2,111,7,112}, {28,17,46,0,0}, {30,7,24,16,25}, {24,34,13,0,0}},
    {{30,4,121,5,122}, {28,4,47,14,48}, {30,11,24,14,25}, {30,16,15,14,16}},
    {{30,6,117,4,118}, {28,6,45,14,46}, {30,11,24,16,25}, {30,30,16,2,17}},
    {{26,8,106,4,107}, {28,8,47,13,48}, {30,7,24,22,25}, {30,22,15,13,16}},
    {{28,10,114,2,115}, {28,19,46,4,47}, {28,28,22,6,23}, {30,33,16,4,17}},
    {{30,8,122,4,123}, {28,22,45,3,46}, {30,8,23,26,24}, {30,12,15,28,16}},
    {{30,3,117,10,118}, {28,3,45,23,46}, {30,4,24,31,25}, {30,11,15,31,16}},
    {{30,7,116,7,117}, {28,21,45,7,46}, {30,1,23,37,24}, {30,19,15,26,16}},
    {{30,5,115,10,116}, {28,19,47,10,48}, {30,15,24,25,25}, {30,23,15,25,16}},
    {{30,13,115,3,116}, {28,2,46,29,47}, {30,42,24,1,25}, {30,23,15,28,16}},
    {{30,17,115,0,0}, {28,10,46,23,47}, {30,10,24,35,25}, {30,19,15,35,16}},
    {{30,17,115,1,116}, {28,14,46,21,47}, {30,29,24,19,25}, {30,11,15,46,16}},
    {{30,13,115,6,116}, {28,14,46,23,47}, {30,44,24,7,25}, {30,59,16,1,17}},
    {{30,12,121,7,122}, {28,12,47,26,48}, {30,39,24,14,25}, {30,22,15,41,16}},
    {{30,6,121,14,122}, {28,6,47,34,48}, {30,46,24,10,25}, {30,2,15,64,16}},
    {{30,17,122,4,123}, {28,29,46,14,47}, {30,49,24,10,25}, {30,24,15,46,16}},
    {{30,4,122,18,123}, {28,13,46,32,47}, {30,48,24,14,25}, {30,42,15,32,16}},
    {{30,20,117,4,118}, {28,40,47,7,48}, {30,43,24,22,25}, {30,10,15,67,16}},
    {{30,19,118,6,119}, {28,18,47,31,48}, {30,34,24,34,25}, {30,20,15,61,16}},
};

static const uint8_t kRemainder[41] = {
    0,
    0, 7, 7, 7, 7, 7,
    0, 0, 0, 0, 0, 0, 0,
    3, 3, 3, 3, 3, 3, 3,
    4, 4, 4, 4, 4, 4, 4,
    3, 3, 3, 3, 3, 3, 3,
    0, 0, 0, 0, 0, 0,
};

static const uint8_t kAlignment[41][8] = {
    {0},
    {0},
    {2, 6, 18},
    {2, 6, 22},
    {2, 6, 26},
    {2, 6, 30},
    {2, 6, 34},
    {3, 6, 22, 38},
    {3, 6, 24, 42},
    {3, 6, 26, 46},
    {3, 6, 28, 50},
    {3, 6, 30, 54},
    {3, 6, 32, 58},
    {3, 6, 34, 62},
    {4, 6, 26, 46, 66},
    {4, 6, 26, 48, 70},
    {4, 6, 26, 50, 74},
    {4, 6, 30, 54, 78},
    {4, 6, 30, 56, 82},
    {4, 6, 30, 58, 86},
    {4, 6, 34, 62, 90},
    {5, 6, 28, 50, 72, 94},
    {5, 6, 26, 50, 74, 98},
    {5, 6, 30, 54, 78, 102},
    {5, 6, 28, 54, 80, 106},
    {5, 6, 32, 58, 84, 110},
    {5, 6, 30, 58, 86, 114},
    {5, 6, 34, 62, 90, 118},
    {6, 6, 26, 50, 74, 98, 122},
    {6, 6, 30, 54, 78, 102, 126},
    {6, 6, 26, 52, 78, 104, 130},
    {6, 6, 30, 56, 82, 108, 134},
    {6, 6, 34, 60, 86, 112, 138},
    {6, 6, 30, 58, 86, 114, 142},
    {6, 6, 34, 62, 90, 118, 146},
    {7, 6, 30, 54, 78, 102, 126, 150},
    {7, 6, 24, 50, 76, 102, 128, 154},
    {7, 6, 28, 54, 80, 106, 132, 158},
    {7, 6, 32, 58, 84, 110, 136, 162},
    {7, 6, 26, 54, 82, 110, 138, 166},
    {7, 6, 30, 58, 86, 114, 142, 170},
};

static const uint8_t kLevelIndex[4] = {1, 0, 3, 2};

static const char kAlphanumeric[] ="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

static int popcount32(uint32_t value)
{
    int count = 0;
    while (value) {
        value &= value - 1;
        count++;
    }
    return count;
}

static void gf_init(charon_qr_gf *gf)
{
    int x = 1;
    for (int i = 0; i < 255; i++) {
        gf->exp[i] = (uint8_t)x;
        gf->log[x] = (uint8_t)i;
        x <<= 1;
        if (x & 0x100) x ^= 0x11D;
    }
    for (int i = 255; i < 512; i++) gf->exp[i] = gf->exp[i - 255];
    gf->log[0] = 0;
}

static uint8_t gf_mul(const charon_qr_gf *gf, uint8_t a, uint8_t b)
{
    if (a == 0 || b == 0) return 0;
    return gf->exp[gf->log[a] + gf->log[b]];
}

static uint8_t gf_div(const charon_qr_gf *gf, uint8_t a, uint8_t b)
{
    if (a == 0) return 0;
    return gf->exp[gf->log[a] + 255 - gf->log[b]];
}

static uint32_t format_word(uint32_t data)
{
    uint32_t rem = data << 10;
    for (int i = 14; i >= 10; i--)
        if (rem & (1u << i)) rem ^= 0x537u << (i - 10);
    return ((data << 10) | (rem & 0x3FFu)) ^ 0x5412u;
}

static uint32_t version_word(uint32_t version)
{
    uint32_t rem = version << 12;
    for (int i = 17; i >= 12; i--)
        if (rem & (1u << i)) rem ^= 0x1F25u << (i - 12);
    return (version << 12) | (rem & 0xFFFu);
}

static int mask_inverts(int mask, int i, int j)
{
    switch (mask) {
    case 0: return (i + j) % 2 == 0;
    case 1: return i % 2 == 0;
    case 2: return j % 3 == 0;
    case 3: return (i + j) % 3 == 0;
    case 4: return (i / 2 + j / 3) % 2 == 0;
    case 5: return (i * j) % 2 + (i * j) % 3 == 0;
    case 6: return ((i * j) % 2 + (i * j) % 3) % 2 == 0;
    default: return ((i + j) % 2 + (i * j) % 3) % 2 == 0;
    }
}

static void mark_function(int size, int version, uint8_t *function)
{
    memset(function, 0, (size_t)size * size);
    for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
            int corner = (r <= 8 && (c <= 8 || c >= size - 8)) || (r >= size - 8 && c <= 8);
            if (corner || r == 6 || c == 6) function[r * size + c] = 1;
        }
    }
    int count = kAlignment[version][0];
    for (int i = 0; i < count; i++) {
        for (int j = 0; j < count; j++) {
            if ((i == 0 && j == 0) || (i == 0 && j == count - 1) || (i == count - 1 && j == 0)) continue;
            int cy = kAlignment[version][1 + i];
            int cx = kAlignment[version][1 + j];
            for (int dy = -2; dy <= 2; dy++)
                for (int dx = -2; dx <= 2; dx++)
                    function[(cy + dy) * size + cx + dx] = 1;
        }
    }
    if (version >= 7) {
        for (int i = 0; i < 6; i++) {
            for (int k = 0; k < 3; k++) {
                function[i * size + size - 11 + k] = 1;
                function[(size - 11 + k) * size + i] = 1;
            }
        }
    }
}

static int read_format(const uint8_t *modules, int size, int *level, int *mask)
{
    static const uint8_t first[15][2] = {
        {8, 0}, {8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5}, {8, 7}, {8, 8},
        {7, 8}, {5, 8}, {4, 8}, {3, 8}, {2, 8}, {1, 8}, {0, 8},
    };
    uint32_t copy1 = 0, copy2 = 0;
    for (int k = 0; k < 15; k++) copy1 = (copy1 << 1) | (modules[first[k][0] * size + first[k][1]] & 1);
    for (int k = 0; k < 7; k++) copy2 = (copy2 << 1) | (modules[(size - 1 - k) * size + 8] & 1);
    for (int k = 0; k < 8; k++) copy2 = (copy2 << 1) | (modules[8 * size + size - 8 + k] & 1);

    int best = 99;
    uint32_t bestData = 0;
    for (uint32_t data = 0; data < 32; data++) {
        uint32_t word = format_word(data);
        int distance = popcount32(copy1 ^ word);
        int other = popcount32(copy2 ^ word);
        if (other < distance) distance = other;
        if (distance < best) {
            best = distance;
            bestData = data;
        }
    }
    if (best > 3) return CharonQRDecodeBadFormat;
    *level = kLevelIndex[bestData >> 3];
    *mask = (int)(bestData & 7);
    return CharonQRDecodeOK;
}

static int read_version(const uint8_t *modules, int size, int version)
{
    uint32_t top = 0, left = 0;
    for (int i = 0; i < 18; i++) {
        top |= (uint32_t)(modules[(i / 3) * size + size - 11 + i % 3] & 1) << i;
        left |= (uint32_t)(modules[(size - 11 + i % 3) * size + i / 3] & 1) << i;
    }
    int best = 99, bestVersion = 0;
    for (int v = 7; v <= 40; v++) {
        uint32_t word = version_word((uint32_t)v);
        int distance = popcount32(top ^ word);
        int other = popcount32(left ^ word);
        if (other < distance) distance = other;
        if (distance < best) {
            best = distance;
            bestVersion = v;
        }
    }
    return best <= 3 && bestVersion == version ? CharonQRDecodeOK : CharonQRDecodeBadVersion;
}

static int rs_correct(const charon_qr_gf *gf, uint8_t *cw, int n, int nsym)
{
    uint8_t syndrome[32] = {0}, lambda[33] = {0}, previous[33] = {0}, saved[33];
    int any = 0;
    for (int j = 0; j < nsym; j++) {
        uint8_t root = gf->exp[j];
        uint8_t s = 0;
        for (int k = 0; k < n; k++) s = gf_mul(gf, s, root) ^ cw[k];
        syndrome[j] = s;
        any |= s;
    }
    if (!any) return 0;

    lambda[0] = 1;
    previous[0] = 1;
    int L = 0, m = 1;
    uint8_t b = 1;
    for (int r = 0; r < nsym; r++) {
        uint8_t d = syndrome[r];
        for (int i = 1; i <= L; i++) d ^= gf_mul(gf, lambda[i], syndrome[r - i]);
        if (d == 0) {
            m++;
            continue;
        }
        uint8_t scale = gf_div(gf, d, b);
        memcpy(saved, lambda, sizeof lambda);
        for (int i = 0; i + m < 33; i++) lambda[i + m] ^= gf_mul(gf, scale, previous[i]);
        if (2 * L <= r) {
            L = r + 1 - L;
            memcpy(previous, saved, sizeof previous);
            b = d;
            m = 1;
        } else {
            m++;
        }
    }
    if (2 * L > nsym) return 1;

    uint8_t omega[32];
    for (int i = 0; i < nsym; i++) {
        uint8_t o = 0;
        for (int j = 0; j <= i && j <= L; j++) o ^= gf_mul(gf, lambda[j], syndrome[i - j]);
        omega[i] = o;
    }

    int found = 0;
    for (int idx = 0; idx < n; idx++) {
        int p = n - 1 - idx;
        uint8_t xinv = gf->exp[(255 - p % 255) % 255];
        uint8_t lv = 0;
        for (int i = L; i >= 0; i--) lv = gf_mul(gf, lv, xinv) ^ lambda[i];
        if (lv != 0) continue;
        uint8_t ov = 0;
        for (int i = nsym - 1; i >= 0; i--) ov = gf_mul(gf, ov, xinv) ^ omega[i];
        uint8_t xsq = gf_mul(gf, xinv, xinv), xp = 1, dv = 0;
        for (int i = 1; i <= L; i += 2) {
            dv ^= gf_mul(gf, lambda[i], xp);
            xp = gf_mul(gf, xp, xsq);
        }
        if (dv == 0) return 1;
        uint8_t locator = gf->exp[p % 255];
        cw[idx] ^= gf_mul(gf, locator, gf_div(gf, ov, dv));
        found++;
    }
    if (found != L) return 1;

    for (int j = 0; j < nsym; j++) {
        uint8_t root = gf->exp[j];
        uint8_t s = 0;
        for (int k = 0; k < n; k++) s = gf_mul(gf, s, root) ^ cw[k];
        if (s) return 1;
    }
    return 0;
}

static int read_bits(charon_qr_reader *reader, int count, uint32_t *value)
{
    if (reader->bits - reader->pos < (size_t)count) return 0;
    uint32_t v = 0;
    for (int i = 0; i < count; i++, reader->pos++) {
        int bit = (reader->bytes[reader->pos >> 3] >> (7 - (reader->pos & 7))) & 1;
        v = (v << 1) | (uint32_t)bit;
    }
    *value = v;
    return 1;
}

static int emit(uint8_t *out, size_t capacity, size_t *length, uint8_t byte)
{
    if (*length >= capacity) return 0;
    out[(*length)++] = byte;
    return 1;
}

static int emit_digits(uint8_t *out, size_t capacity, size_t *length, uint32_t v, int n)
{
    uint32_t place = 1;
    for (int k = 1; k < n; k++) place *= 10;
    for (int k = 0; k < n; k++, place /= 10)
        if (!emit(out, capacity, length, (uint8_t)('0' + (v / place) % 10))) return 0;
    return 1;
}

static int parse_segments(const uint8_t *data, size_t count, int version, uint8_t *out, size_t capacity, size_t *length,
                          int *mode)
{
    charon_qr_reader reader = {data, count * 8, 0};
    int seen = 0;
    *length = 0;
    *mode = CharonQRModeNone;
    for (;;) {
        uint32_t indicator, characters;
        if (reader.bits - reader.pos < 4) break;
        read_bits(&reader, 4, &indicator);
        if (indicator == 0) break;
        int segmentMode;
        int countBits;
        if (indicator == 1) {
            segmentMode = CharonQRModeNumeric;
            countBits = version <= 9 ? 10 : version <= 26 ? 12 : 14;
        } else if (indicator == 2) {
            segmentMode = CharonQRModeAlphanumeric;
            countBits = version <= 9 ? 9 : version <= 26 ? 11 : 13;
        } else if (indicator == 4) {
            segmentMode = CharonQRModeByte;
            countBits = version <= 9 ? 8 : 16;
        } else {
            return CharonQRDecodeUnsupported;
        }
        if (!read_bits(&reader, countBits, &characters)) return CharonQRDecodeMalformed;

        if (!seen) *mode = segmentMode;
        else if (*mode != segmentMode) *mode = CharonQRModeMixed;
        seen = 1;

        uint32_t left = characters;
        if (segmentMode == CharonQRModeNumeric) {
            while (left >= 3) {
                uint32_t v;
                if (!read_bits(&reader, 10, &v) || v > 999) return CharonQRDecodeMalformed;
                if (!emit_digits(out, capacity, length, v, 3)) return CharonQRDecodeTooLong;
                left -= 3;
            }
            if (left == 2 || left == 1) {
                uint32_t v;
                if (!read_bits(&reader, left == 2 ? 7 : 4, &v) || v >= (left == 2 ? 100u : 10u))
                    return CharonQRDecodeMalformed;
                if (!emit_digits(out, capacity, length, v, (int)left)) return CharonQRDecodeTooLong;
            }
        } else if (segmentMode == CharonQRModeAlphanumeric) {
            while (left >= 2) {
                uint32_t v;
                if (!read_bits(&reader, 11, &v) || v >= 45 * 45) return CharonQRDecodeMalformed;
                if (!emit(out, capacity, length, (uint8_t)kAlphanumeric[v / 45])) return CharonQRDecodeTooLong;
                if (!emit(out, capacity, length, (uint8_t)kAlphanumeric[v % 45])) return CharonQRDecodeTooLong;
                left -= 2;
            }
            if (left == 1) {
                uint32_t v;
                if (!read_bits(&reader, 6, &v) || v >= 45) return CharonQRDecodeMalformed;
                if (!emit(out, capacity, length, (uint8_t)kAlphanumeric[v])) return CharonQRDecodeTooLong;
            }
        } else {
            while (left > 0) {
                uint32_t v;
                if (!read_bits(&reader, 8, &v)) return CharonQRDecodeMalformed;
                if (!emit(out, capacity, length, (uint8_t)v)) return CharonQRDecodeTooLong;
                left--;
            }
        }
    }
    return CharonQRDecodeOK;
}

int CharonQRDecode(const uint8_t *modules, int size, uint8_t *out, size_t capacity, size_t *length, int *mode)
{
    if (length) *length = 0;
    if (mode) *mode = CharonQRModeNone;
    if (!modules || !out || !length || !mode) return CharonQRDecodeBadArgument;
    if (size < 21 || size > CHARON_QR_MAX_SIZE || (size - 17) % 4 != 0) return CharonQRDecodeBadSize;
    int version = (size - 17) / 4;

    int level, maskIndex;
    int status = read_format(modules, size, &level, &maskIndex);
    if (status != CharonQRDecodeOK) return status;
    if (version >= 7) {
        status = read_version(modules, size, version);
        if (status != CharonQRDecodeOK) return status;
    }

    uint8_t function[CHARON_QR_MAX_SIZE * CHARON_QR_MAX_SIZE];
    mark_function(size, version, function);

    const charon_qr_blocks *spec = &kBlocks[version][level];
    int blocks = spec->b1 + spec->b2;
    int total = spec->b1 * (spec->d1 + spec->ec) + spec->b2 * (spec->d2 + spec->ec);

    uint8_t stream[CHARON_QR_MAX_CODEWORDS] = {0};
    int bits = 0, dataModules = 0, upward = 1;
    for (int col = size - 1; col > 0; col -= 2) {
        if (col == 6) col = 5;
        for (int step = 0; step < size; step++) {
            int r = upward ? size - 1 - step : step;
            for (int c = col; c >= col - 1; c--) {
                if (function[r * size + c]) continue;
                dataModules++;
                if (bits < total * 8) {
                    int bit = (modules[r * size + c] & 1) ^ mask_inverts(maskIndex, r, c);
                    stream[bits >> 3] = (uint8_t)((stream[bits >> 3] << 1) | bit);
                    bits++;
                }
            }
        }
        upward = !upward;
    }
    if (dataModules != total * 8 + kRemainder[version]) return CharonQRDecodeLayout;

    uint8_t block[CHARON_QR_MAX_BLOCKS][CHARON_QR_MAX_BLOCK];
    int dataLength[CHARON_QR_MAX_BLOCKS], blockLength[CHARON_QR_MAX_BLOCKS];
    int maxData = 0;
    for (int b = 0; b < blocks; b++) {
        dataLength[b] = b < spec->b1 ? spec->d1 : spec->d2;
        blockLength[b] = dataLength[b] + spec->ec;
        if (dataLength[b] > maxData) maxData = dataLength[b];
    }
    int pos = 0;
    for (int i = 0; i < maxData; i++)
        for (int b = 0; b < blocks; b++)
            if (i < dataLength[b]) block[b][i] = stream[pos++];
    for (int i = 0; i < spec->ec; i++)
        for (int b = 0; b < blocks; b++)
            block[b][dataLength[b] + i] = stream[pos++];

    charon_qr_gf gf;
    gf_init(&gf);
    uint8_t data[CHARON_QR_MAX_CODEWORDS];
    size_t dataCount = 0;
    for (int b = 0; b < blocks; b++) {
        if (rs_correct(&gf, block[b], blockLength[b], spec->ec)) return CharonQRDecodeUncorrectable;
        memcpy(data + dataCount, block[b], (size_t)dataLength[b]);
        dataCount += (size_t)dataLength[b];
    }

    status = parse_segments(data, dataCount, version, out, capacity, length, mode);
    if (status != CharonQRDecodeOK) {
        *length = 0;
        *mode = CharonQRModeNone;
    }
    return status;
}
