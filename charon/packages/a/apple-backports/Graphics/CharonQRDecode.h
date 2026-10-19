#ifndef CHARON_QR_DECODE_H
#define CHARON_QR_DECODE_H

#include <stddef.h>
#include <stdint.h>

// The QR decoder of ISO/IEC 18004: a square of modules in, the message bytes out. modules is size * size bytes, row by row,
// top row first, a non-zero byte a dark module. size is 17 + 4v for version v = 1...40, so 21...177.

// The mode of the message: the segment mode of a symbol with one kind of segment, CharonQRModeMixed for two or more kinds,
// and 0 for a symbol whose first mode indicator is the terminator (an empty message).
enum {
    CharonQRModeNone = 0,
    CharonQRModeNumeric = 1,
    CharonQRModeAlphanumeric = 2,
    CharonQRModeByte = 4,
    CharonQRModeMixed = 8,
};

enum {
    CharonQRDecodeOK = 0,
    CharonQRDecodeBadArgument = -1,     // a null pointer
    CharonQRDecodeBadSize = -2,         // not 17 + 4v for v = 1...40
    CharonQRDecodeBadFormat = -3,       // no format information within 3 bit errors of a valid word, in either copy
    CharonQRDecodeBadVersion = -4,      // version 7 and up: the version information is not the size's version
    CharonQRDecodeLayout = -5,          // the data modules do not number the standard's codewords plus remainder bits
    CharonQRDecodeUncorrectable = -6,   // a block has more errors than its error correction can fix
    CharonQRDecodeUnsupported = -7,     // a mode the decoder does not read: Kanji, ECI, FNC1 or structured append
    CharonQRDecodeMalformed = -8,       // a count, a character or a field the standard does not allow
    CharonQRDecodeTooLong = -9,         // the message does not fit in capacity bytes
};

// Decodes the symbol into out, which holds capacity bytes. On success *length is the message length and *mode its mode.
// On failure nothing is said about out, and *length and *mode are zero.
int CharonQRDecode(const uint8_t *modules, int size, uint8_t *out, size_t capacity, size_t *length, int *mode);

#endif
