#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "RevenantHAPBignum.h"

static int hex_digit(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int read_value(BigNum *out, const char *text)
{
    size_t length = strlen(text);
    if (!length || (length % 2) != 0)
        return 0;
    uint8_t bytes[BN_LIMBS * 4];
    for (size_t i = 0; i < length / 2; ++i) {
        int high = hex_digit(text[2 * i]), low = hex_digit(text[2 * i + 1]);
        if (high < 0 || low < 0)
            return 0;
        bytes[i] = (uint8_t)((high << 4) | low);
    }
    revenant_bn_from_bytes_be(out, bytes, length / 2);
    return 1;
}

int main(void)
{
    char line[3 * (BN_LIMBS * 4) * 2 + 32];
    while (fgets(line, sizeof line, stdin)) {
        char *fields[4] = { 0, 0, 0, 0 };
        int count = 0;
        char *cursor = line;
        while (count < 4) {
            fields[count++] = cursor;
            char *tab = strchr(cursor, '\t');
            char *end = strpbrk(cursor, "\r\n");
            if (end)
                *end = 0;
            if (!tab)
                break;
            *tab = 0;
            cursor = tab + 1;
        }
        if (count < 4) {
            printf("-\n");
            continue;
        }
        BigNum a, b, n, out;
        BigNumMont mont;
        if (!read_value(&a, fields[1]) || !read_value(&b, fields[2]) || !read_value(&n, fields[3])) {
            printf("-\n");
            continue;
        }
        revenant_bn_mont_prepare(&mont, &n);
        if (strcmp(fields[0], "pow") == 0)
            revenant_bn_mont_pow(&mont, &out, &a, &b);
        else
            revenant_bn_mont_mul(&mont, &out, &a, &b);
        size_t needed = revenant_bn_byte_length(&out);
        uint8_t bytes[BN_LIMBS * 4];
        revenant_bn_to_bytes_be(bytes, needed ? needed : 1, &out);
        for (size_t i = 0; i < (needed ? needed : 1); ++i)
            printf("%02X", bytes[i]);
        printf("\n");
    }
    return 0;
}
