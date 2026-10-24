#include <stdint.h>
#include <stdio.h>
#include "revenant/guest_memory.h"

#define SIZE (256u * 1024u)
#define PASSES 4u
#define DIM 64u

static uint32_t crc_table[256];
static uint8_t buffer[SIZE];
static int32_t a[DIM][DIM];
static int32_t b[DIM][DIM];
static int32_t c[DIM][DIM];

static void crc_init(void)
{
    for (uint32_t i = 0; i < 256u; ++i) {
        uint32_t value = i;
        for (int k = 0; k < 8; ++k) {
            value = (value & 1u) ? 0xEDB88320u ^ (value >> 1) : value >> 1;
        }
        crc_table[i] = value;
    }
}

static uint32_t crc32(const uint8_t *data, size_t size)
{
    uint32_t value = 0xFFFFFFFFu;
    for (size_t i = 0; i < size; ++i) {
        value = crc_table[(value ^ data[i]) & 0xFFu] ^ (value >> 8);
    }
    return value ^ 0xFFFFFFFFu;
}

static uint64_t fnv1a(const uint8_t *data, size_t size)
{
    uint64_t hash = 0xCBF29CE484222325ull;
    for (size_t i = 0; i < size; ++i) {
        hash ^= data[i];
        hash *= 0x100000001B3ull;
    }
    return hash;
}

static uint32_t matrix_product(void)
{
    for (uint32_t i = 0; i < DIM; ++i) {
        for (uint32_t j = 0; j < DIM; ++j) {
            a[i][j] = (int32_t)(i * 31u + j * 7u) - 97;
            b[i][j] = (int32_t)(i * 13u + j * 29u) - 61;
        }
    }
    for (uint32_t i = 0; i < DIM; ++i) {
        for (uint32_t j = 0; j < DIM; ++j) {
            int32_t sum = 0;
            for (uint32_t k = 0; k < DIM; ++k) {
                sum += a[i][k] * b[k][j];
            }
            c[i][j] = sum;
        }
    }
    uint32_t checksum = 0;
    for (uint32_t i = 0; i < DIM; ++i) {
        for (uint32_t j = 0; j < DIM; ++j) {
            checksum = checksum * 31u + (uint32_t)c[i][j];
        }
    }
    return checksum;
}

int main(void)
{
    uint32_t state = 12345u;
    for (size_t i = 0; i < SIZE; ++i) {
        state = state * 1103515245u + 12345u;
        buffer[i] = (uint8_t)(state >> 16);
    }
    crc_init();
    uint32_t crc = 0;
    uint64_t fnv = 0;
    uint32_t matrix = 0;
    for (uint32_t pass = 0; pass < PASSES; ++pass) {
        crc ^= crc32(buffer, SIZE);
        fnv ^= fnv1a(buffer, SIZE);
        matrix += matrix_product();
    }
    uint32_t checksum = crc ^ (uint32_t)fnv ^ (uint32_t)(fnv >> 32) ^ matrix;
    revenant_guest_memory_t memory;
    revenant_guest_memory_read_self(&memory);
    printf("bench compute checksum=%u iterations=%u virtual=%llu resident=%llu peak=%llu peak_known=%d\n",
        checksum, (unsigned)(PASSES * SIZE), (unsigned long long)memory.virtual_bytes,
        (unsigned long long)memory.resident_bytes, (unsigned long long)memory.peak_resident_bytes,
        (int)memory.peak_known);
    return 0;
}
