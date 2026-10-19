#ifndef CHARON_NDEF_H
#define CHARON_NDEF_H

#include <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CharonNDEFMaxTypeLength 255
#define CharonNDEFMaxIDLength 255
#define CharonNDEFMaxChunkSize 0x7f

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
    int hasIdentifierField;
    const uint8_t *payload;
    size_t payloadLength;
} CharonNDEFRecord;

size_t CharonNDEFRecordLength(const CharonNDEFRecord *record);

size_t CharonNDEFRecordEncode(const CharonNDEFRecord *record, uint8_t *out, size_t capacity);

size_t CharonNDEFRecordDecode(const uint8_t *bytes, size_t length, CharonNDEFRecord *record);

@class NFCNDEFMessage;
NSData *CharonNDEFEncodedRecords(NFCNDEFMessage *message);

extern const char *const CharonNDEFURIPrefixes[36];
#define CharonNDEFURIPrefixCount 36

#endif
