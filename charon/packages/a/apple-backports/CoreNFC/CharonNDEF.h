// CharonNDEF.h - the NDEF record shape of the NFC Forum NDEF Technical Specification, shared by the
// port's NFCNDEFPayload and NFCNDEFMessage.
//
// A record is a header byte, a type length, a payload length of one or four bytes, an ID length of one
// byte, and then the type, the ID and the payload:
//
//     bit   7   6   5   4   3 2 1  0
//          MB  ME  SR  IL  TNF   CF
//
//   MB  the first record of a message, ME the last; the two together are how a reader knows where the
//       message ends inside a tag's larger blob.
//   SR  short record: the payload length is one byte rather than four.
//   TNF the type name format: 0 empty, 1 well known, 2 media, 3 absolute URI, 4 NFC external,
//       5 unknown, 6 unchanged, 7 reserved.
//   CF  chunked: this record continues the one before it, and a chunked payload's first byte is its
//       marker - 0 in the first chunk and the chunk number in every one after it.
//   IL  the ID length field is present, and so is the field itself only when the record has an
//       identifier to measure. The specification keeps that field one byte wide, and so does the port.
//
// The reuse rule points at what is taken rather than typed, and this file is the shape of the
// specification written out: the record layout, the well-known type names of the URI and text RTDs, and
// the URI prefix table, which is the NFC Forum URI RTD's own 36 entries.

#ifndef CHARON_NDEF_H
#define CHARON_NDEF_H

#include <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CharonNDEFMaxTypeLength 255
#define CharonNDEFMaxIDLength 255
#define CharonNDEFMaxChunkSize 0x7f

// The text RTD's status byte: its top bit is the encoding (0 UTF-8, 1 UTF-16) and its low six the
// length of the language code.
#define CharonNDEFTextUTF16 0x80
#define CharonNDEFTextLanguageLengthMask 0x3f

typedef struct {
    uint8_t format;
    int first;
    int last;
    int continuation;
    uint8_t type[CharonNDEFMaxTypeLength];
    size_t typeLength;
    uint8_t identifier[CharonNDEFMaxIDLength];
    size_t identifierLength;
    int hasIdentifierField;   // the header's IL: the ID length byte is there whenever the flag is set,
                             // whatever the length it names
    const uint8_t *payload;
    size_t payloadLength;
} CharonNDEFRecord;

// The bytes one record occupies, its own header included, or 0 when a field is wider than the one-byte
// length fields can say.
size_t CharonNDEFRecordLength(const CharonNDEFRecord *record);

// Writes the record, or writes nothing: 0 when it does not fit the buffer, and never a partial record.
size_t CharonNDEFRecordEncode(const CharonNDEFRecord *record, uint8_t *out, size_t capacity);

// Reads the record at the front of `bytes` and answers how many it occupies, or 0 when the bytes are
// not a whole record of the length they claim.
size_t CharonNDEFRecordDecode(const uint8_t *bytes, size_t length, CharonNDEFRecord *record);

// The bytes a message encodes to, which -length weighs and the differential reads back. It is a
// function rather than a method because the encoded bytes are the port's own state, kept in the
// object's class extension and not in any header of the framework.
@class NFCNDEFMessage;
NSData *CharonNDEFEncodedRecords(NFCNDEFMessage *message);

// The well-known URI prefixes of the NFC Forum URI RTD specification, in its own order, index 0 the
// empty prefix.
extern const char *const CharonNDEFURIPrefixes[36];
#define CharonNDEFURIPrefixCount 36

#endif
