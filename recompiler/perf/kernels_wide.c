#include <stddef.h>
#include <stdint.h>

static uint32_t rotr(uint32_t x, unsigned n)
{
    return (x >> n) | (x << (32 - n));
}

uint64_t kw_crc32(uint8_t *arena, uint64_t size)
{
    uint32_t table[256];
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t c = i;
        for (int k = 0; k < 8; k++)
            c = c & 1 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
        table[i] = c;
    }
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < size; i++)
        c = table[(c ^ arena[i]) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFu;
}

uint64_t kw_sha256(uint8_t *arena, uint64_t size)
{
    static const uint32_t k[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
    uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
    for (size_t block = 0; block + 64 <= size; block += 64) {
        uint32_t w[64];
        for (int i = 0; i < 16; i++)
            w[i] = (uint32_t)arena[block + i * 4] << 24 | (uint32_t)arena[block + i * 4 + 1] << 16 |
                   (uint32_t)arena[block + i * 4 + 2] << 8 | arena[block + i * 4 + 3];
        for (int i = 16; i < 64; i++) {
            uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
            uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; i++) {
            uint32_t t1 = hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + k[i] + w[i];
            uint32_t t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    return (uint64_t)h[0] << 32 | h[7];
}

uint64_t kw_fnv64(uint8_t *arena, uint64_t size)
{
    uint64_t hash = 0xcbf29ce484222325ull;
    for (size_t i = 0; i < size; i++)
        hash = (hash ^ arena[i]) * 0x100000001b3ull;
    return hash;
}

static void sort_longs(int64_t *values, int64_t low, int64_t high)
{
    while (low < high) {
        int64_t pivot = values[(low + high) / 2], i = low, j = high;
        while (i <= j) {
            while (values[i] < pivot)
                i++;
            while (values[j] > pivot)
                j--;
            if (i <= j) {
                int64_t t = values[i];
                values[i++] = values[j];
                values[j--] = t;
            }
        }
        if (j - low < high - i) {
            sort_longs(values, low, j);
            low = i;
        } else {
            sort_longs(values, i, high);
            high = j;
        }
    }
}

uint64_t kw_sort(uint8_t *arena, uint64_t size)
{
    int64_t *values = (int64_t *)arena;
    size_t count = size;
    uint32_t state = 2463534242u;
    for (size_t i = 0; i < count; i++) {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        values[i] = (int64_t)(state % 1000003u);
    }
    sort_longs(values, 0, (int64_t)count - 1);
    uint64_t sum = 0;
    for (size_t i = 0; i < count; i += 97)
        sum = sum * 31 + (uint64_t)values[i];
    return sum;
}

struct node {
    struct node *next;
    struct node *other;
    int64_t value;
    int flags;
};

uint64_t kw_list(uint8_t *arena, uint64_t size)
{
    size_t count = size;
    struct node *nodes = (struct node *)arena;
    for (size_t i = 0; i < count; i++) {
        nodes[i].next = i + 1 < count ? &nodes[(i * 7 + 1) % count] : 0;
        nodes[i].other = &nodes[(i * 13) % count];
        nodes[i].value = (int64_t)(i % 1000);
        nodes[i].flags = (int)(i & 3);
    }
    uint64_t sum = 0;
    struct node *n = &nodes[0];
    for (size_t steps = 0; n && steps < count * 4; steps++) {
        sum += (uint64_t)n->value + (uint64_t)n->other->value * (uint64_t)n->flags;
        n = n->next ? n->next : n->other;
    }
    return sum;
}

struct shape {
    double x, y, w, h;
    int64_t tag;
};

uint64_t kw_geometry(uint8_t *arena, uint64_t size)
{
    size_t count = size;
    struct shape *shapes = (struct shape *)arena;
    for (size_t i = 0; i < count; i++) {
        shapes[i].x = (double)(i % 320);
        shapes[i].y = (double)(i * 44 % 480);
        shapes[i].w = 10.0 + (double)(i % 7);
        shapes[i].h = 44.0;
        shapes[i].tag = (int64_t)i;
    }
    double area = 0;
    int64_t hits = 0;
    for (size_t i = 0; i + 1 < count; i++) {
        struct shape *a = &shapes[i], *b = &shapes[i + 1];
        double left = a->x > b->x ? a->x : b->x;
        double right = a->x + a->w < b->x + b->w ? a->x + a->w : b->x + b->w;
        double top = a->y > b->y ? a->y : b->y;
        double bottom = a->y + a->h < b->y + b->h ? a->y + a->h : b->y + b->h;
        if (right > left && bottom > top) {
            area += (right - left) * (bottom - top);
            hits += a->tag & 1;
        }
    }
    return (uint64_t)area ^ (uint64_t)hits << 40;
}

uint64_t kw_matrix(uint8_t *arena, uint64_t size)
{
    int n = (int)size;
    double *a = (double *)arena, *b = a + n * n, *c = b + n * n;
    for (int i = 0; i < n * n; i++) {
        a[i] = (double)(i % 17) / 3.0;
        b[i] = (double)(i % 13) / 7.0;
        c[i] = 0;
    }
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++)
            for (int j = 0; j < n; j++)
                c[i * n + j] += a[i * n + k] * b[k * n + j];
    double trace = 0;
    for (int i = 0; i < n; i++)
        trace += c[i * n + i];
    return (uint64_t)(trace * 1000);
}

uint64_t kw_text(uint8_t *arena, uint64_t size)
{
    static const char words[] = "the quick brown fox jumps over the lazy dog while seven wizards quietly vex jumbo ";
    size_t length = sizeof words - 1;
    for (size_t i = 0; i < size; i++)
        arena[i] = (uint8_t)words[i % length];
    arena[size - 1] = 0;
    uint64_t count = 0, longest = 0, hash = 0;
    const uint8_t *p = arena;
    while (*p) {
        while (*p == ' ')
            p++;
        const uint8_t *start = p;
        while (*p && *p != ' ') {
            hash = hash * 33 + *p;
            p++;
        }
        size_t word = (size_t)(p - start);
        if (word) {
            count++;
            if (word > longest)
                longest = word;
        }
    }
    return count * 1000003 + longest + hash;
}
