/* The bignum HAP's pairing arithmetic is written on: a reader, and the cases come from run.sh.
 *
 * One case per line, TAB separated:
 *
 *   mul|pow    left    right    modulus
 *
 * in hex, most significant first, and the answer is printed the same way, one line per case, so that
 * run.sh can generate the cases with an independent implementation and diff the two answers. The
 * operands are written at whatever width they are: a narrow value is a narrow value, and reading it
 * padded is the mistake this file exists to keep visible.
 *
 * The two shapes are the point. `pow` is what a modular exponentiation makes and what the first
 * 72-case check covered: two full-width operands. `mul` is what SRP-6a makes and what that check
 * never reached: a narrow `k`, `x` or `u` against a full-width `v`, a narrow value reduced on its own,
 * and a 2000-bit value against a narrow one. The defect those found is in `mont_finish`: a modulus
 * that fills its own width has 2n above R, so the reduced value carries a limb past R, and the code
 * used to read only the low limbs and subtract the modulus *because* that limb was set. */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "CharonHAPBignum.h"

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
    charon_bn_from_bytes_be(out, bytes, length / 2);
    return 1;
}

int main(void)
{
    char line[3 * (BN_LIMBS * 4) * 2 + 32];
    while (fgets(line, sizeof line, stdin)) {
        /* Four fields, split on tabs: the kind and three hex numbers. A short line is skipped rather
         * than read past, so a malformed case is a "-" in the answers and a diff, not a crash. */
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
        charon_bn_mont_prepare(&mont, &n);
        if (strcmp(fields[0], "pow") == 0)
            charon_bn_mont_pow(&mont, &out, &a, &b);
        else
            charon_bn_mont_mul(&mont, &out, &a, &b);
        size_t needed = charon_bn_byte_length(&out);
        uint8_t bytes[BN_LIMBS * 4];
        charon_bn_to_bytes_be(bytes, needed ? needed : 1, &out);
        for (size_t i = 0; i < (needed ? needed : 1); ++i)
            printf("%02X", bytes[i]);
        printf("\n");
    }
    return 0;
}
