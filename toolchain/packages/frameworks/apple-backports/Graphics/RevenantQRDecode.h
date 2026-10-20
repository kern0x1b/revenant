#ifndef REVENANT_QR_DECODE_H
#define REVENANT_QR_DECODE_H

#include <stddef.h>
#include <stdint.h>

enum {
    RevenantQRModeNone = 0,
    RevenantQRModeNumeric = 1,
    RevenantQRModeAlphanumeric = 2,
    RevenantQRModeByte = 4,
    RevenantQRModeMixed = 8,
};

enum {
    RevenantQRDecodeOK = 0,
    RevenantQRDecodeBadArgument = -1,
    RevenantQRDecodeBadSize = -2,
    RevenantQRDecodeBadFormat = -3,
    RevenantQRDecodeBadVersion = -4,
    RevenantQRDecodeLayout = -5,
    RevenantQRDecodeUncorrectable = -6,
    RevenantQRDecodeUnsupported = -7,
    RevenantQRDecodeMalformed = -8,
    RevenantQRDecodeTooLong = -9,
};

int RevenantQRDecode(const uint8_t *modules, int size, uint8_t *out, size_t capacity, size_t *length, int *mode);

#endif
