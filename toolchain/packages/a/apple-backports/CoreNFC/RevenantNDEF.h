#ifndef REVENANT_NDEF_H
#define REVENANT_NDEF_H

#include <Foundation/Foundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define RevenantNDEFMaxTypeLength 255
#define RevenantNDEFMaxIDLength 255
#define RevenantNDEFMaxChunkSize 0x7f

#define RevenantNDEFTextUTF16 0x80
#define RevenantNDEFTextLanguageLengthMask 0x3f

typedef struct {
    uint8_t format;
    int first;
    int last;
    int continuation;
    uint8_t type[RevenantNDEFMaxTypeLength];
    size_t typeLength;
    uint8_t identifier[RevenantNDEFMaxIDLength];
    size_t identifierLength;
    int hasIdentifierField;
    const uint8_t *payload;
    size_t payloadLength;
} RevenantNDEFRecord;

size_t RevenantNDEFRecordLength(const RevenantNDEFRecord *record);

size_t RevenantNDEFRecordEncode(const RevenantNDEFRecord *record, uint8_t *out, size_t capacity);

size_t RevenantNDEFRecordDecode(const uint8_t *bytes, size_t length, RevenantNDEFRecord *record);

@class NFCNDEFMessage;
NSData *RevenantNDEFEncodedRecords(NFCNDEFMessage *message);

extern const char *const RevenantNDEFURIPrefixes[36];
#define RevenantNDEFURIPrefixCount 36

#endif
