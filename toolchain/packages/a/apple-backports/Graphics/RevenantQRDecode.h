#ifndef CHARON_QR_DECODE_H
#define CHARON_QR_DECODE_H

#include <stddef.h>
#include <stdint.h>

enum {
    CharonQRModeNone = 0,
    CharonQRModeNumeric = 1,
    CharonQRModeAlphanumeric = 2,
    CharonQRModeByte = 4,
    CharonQRModeMixed = 8,
};

enum {
    CharonQRDecodeOK = 0,
    CharonQRDecodeBadArgument = -1,
    CharonQRDecodeBadSize = -2,
    CharonQRDecodeBadFormat = -3,
    CharonQRDecodeBadVersion = -4,
    CharonQRDecodeLayout = -5,
    CharonQRDecodeUncorrectable = -6,
    CharonQRDecodeUnsupported = -7,
    CharonQRDecodeMalformed = -8,
    CharonQRDecodeTooLong = -9,
};

int CharonQRDecode(const uint8_t *modules, int size, uint8_t *out, size_t capacity, size_t *length, int *mode);

#endif
