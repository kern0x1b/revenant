#import <Foundation/Foundation.h>
#import "CoreNFC/CoreNFC.h"
#import "check.h"
#import "CharonNDEF.h"

static void check_named(BOOL passed, NSString *name, NSString *detail)
{
    charon_check(passed, [name UTF8String], detail);
}

static NSData *bytes(const unsigned char *values, size_t length)
{
    return [NSData dataWithBytes:values length:length];
}

static NSData *TextVector(void)
{
    const unsigned char v[] = {0xE2, 0x01, 0x08, 0x54, 0x02, 0x65, 0x6E, 0x48, 0x65, 0x6C, 0x6C, 0x6F};
    return bytes(v, sizeof v);
}

static NSData *URIVector(void)
{
    const unsigned char v[] = {0xE2, 0x01, 0x0C, 0x55, 0x01, 0x65, 0x78, 0x61, 0x6D, 0x70, 0x6C, 0x65,
                               0x2E, 0x63, 0x6F, 0x6D};
    return bytes(v, sizeof v);
}

static NSData *LongRecordVector(size_t payloadLength)
{
    NSMutableData *data = [NSMutableData data];
    const unsigned char head[] = {0xD4, 0x04, (unsigned char)(payloadLength >> 24),
                                  (unsigned char)(payloadLength >> 16), (unsigned char)(payloadLength >> 8),
                                  (unsigned char)payloadLength, 0x00, 0x74, 0x65, 0x73, 0x74};
    [data appendBytes:head length:sizeof head];
    for (size_t index = 0; index < payloadLength; index++) {
        unsigned char filler = (unsigned char)(index & 0xff);
        [data appendBytes:&filler length:1];
    }
    const unsigned char tail[] = {0x62, 0x01, 0x01, 0x51, 0x51};
    [data appendBytes:tail length:sizeof tail];
    return data;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    BOOL mutated = argc > 1 && strcmp(argv[1], "--mutated") == 0;

    NSData *text = TextVector();
    if (mutated) {
        NSMutableData *changed = [text mutableCopy];
        ((unsigned char *)changed.mutableBytes)[2] = 0x07;
        text = changed;
    }
    NFCNDEFMessage *fromText = [NFCNDEFMessage ndefMessageWithData:text];
    check_named(fromText.records.count == 1, @"the text vector is one record", [NSString stringWithFormat:@"%lu", (unsigned long)fromText.records.count]);
    NFCNDEFPayload *textRecord = fromText.records.firstObject;
    check_named(textRecord.typeNameFormat == NFCTypeNameFormatNFCWellKnown, @"whose type name format is well known",
                 [NSString stringWithFormat:@"%u", (unsigned)textRecord.typeNameFormat]);
    check_named([textRecord.type isEqualToData:[@"T" dataUsingEncoding:NSUTF8StringEncoding]], @"and whose type is the text RTD's T", textRecord.type);
    check_named(textRecord.identifier == nil, @"and no identifier at all, because the header's IL is clear", textRecord.identifier);
    NSLocale *locale = nil;
    NSString *hello = [textRecord wellKnownTypeTextPayloadWithLocale:&locale];
    check_named([hello isEqualToString:@"Hello"], @"and whose payload reads back as the text it was", hello);
    check_named([locale.localeIdentifier isEqualToString:@"en"], @"in the language its status byte names", locale.localeIdentifier);
    check_named(fromText.length == text.length, @"and whose length is the length of the vector",
                 [NSString stringWithFormat:@"%lu against %lu", (unsigned long)fromText.length, (unsigned long)text.length]);

    NFCNDEFMessage *fromURI = [NFCNDEFMessage ndefMessageWithData:URIVector()];
    check_named(fromURI.records.count == 1, @"the URI vector is one record", nil);
    NSURL *url = [fromURI.records.firstObject wellKnownTypeURIPayload];
    check_named([url.absoluteString isEqualToString:@"http://www.example.com"], @"whose payload reads back as the URI it was", url.absoluteString);
    check_named(fromURI.length == URIVector().length, @"and whose length is the length of the vector", nil);

    NSData *long300 = LongRecordVector(300);
    NFCNDEFMessage *fromLong = [NFCNDEFMessage ndefMessageWithData:long300];
    check_named(fromLong.records.count == 2, @"a 300 byte payload and its tail are two records", [NSString stringWithFormat:@"%lu", (unsigned long)fromLong.records.count]);
    check_named([fromLong.records.firstObject.payload isEqualToData:[long300 subdataWithRange:NSMakeRange(11, 300)]],
                 @"and the first carries the 300 bytes the four byte length field named", nil);
    check_named([fromLong.records.firstObject.identifier isEqualToData:[NSData data]], @"and an ID field that is there and empty",
                 [fromLong.records.firstObject.identifier description]);
    check_named([fromLong.records.lastObject.type isEqualToData:[@"Q" dataUsingEncoding:NSUTF8StringEncoding]],
                 @"and the second the type that follows", [fromLong.records.lastObject.type description]);

    NFCNDEFPayload *text2 = [NFCNDEFPayload wellKnownTypeTextPayloadWithString:@"Hello" locale:[NSLocale localeWithLocaleIdentifier:@"en"]];
    NFCNDEFMessage *built = [[NFCNDEFMessage alloc] initWithNDEFRecords:@[text2]];
    check_named(built.length == text.length, @"a message the port builds weighs what the vector weighs",
                 [NSString stringWithFormat:@"%lu against %lu", (unsigned long)built.length, (unsigned long)text.length]);
    NFCNDEFMessage *reread = [NFCNDEFMessage ndefMessageWithData:CharonNDEFEncodedRecords(built)];
    check_named([reread.records.firstObject.payload isEqualToData:textRecord.payload], @"and its own bytes read back as the same payload",
                 [reread.records.firstObject.payload description]);
    NFCNDEFPayload *emptyID = [[NFCNDEFPayload alloc] initWithFormat:NFCTypeNameFormatEmpty type:[NSData data]
                                                          identifier:[NSData data] payload:[NSData data]];
    NFCNDEFMessage *emptyIDMessage = [[NFCNDEFMessage alloc] initWithNDEFRecords:@[emptyID]];
    check_named(emptyIDMessage.length == 3, @"an empty identifier is written with no ID field, three bytes in all",
                 [NSString stringWithFormat:@"%lu bytes", (unsigned long)emptyIDMessage.length]);

    NSMutableData *ten = [NSMutableData data];
    for (int index = 0; index < 10; index++) {
        unsigned char byte = (unsigned char)('a' + index);
        [ten appendBytes:&byte length:1];
    }
    NFCNDEFPayload *chunked = [[NFCNDEFPayload alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown
                                                             type:[@"T" dataUsingEncoding:NSUTF8StringEncoding]
                                                        identifier:nil payload:ten chunkSize:4];
    NFCNDEFMessage *chunkedMessage = [[NFCNDEFMessage alloc] initWithNDEFRecords:@[chunked]];
    NSData *chunkedBytes = CharonNDEFEncodedRecords(chunkedMessage);
    check_named(chunkedBytes.length == 23, @"a ten byte payload chunked by four is three records of 4, 4 and 2 bytes with their markers",
                 [NSString stringWithFormat:@"%lu bytes", (unsigned long)chunkedBytes.length]);
    check_named((((const unsigned char *)chunkedBytes.bytes)[0] & 0x01) == 0, @"whose first record is not a continuation", nil);
    const unsigned char *raw = chunkedBytes.bytes;
    size_t at = 0;
    for (int record = 0; record < 3; record++) {
        check_named(at + 3 <= chunkedBytes.length, [NSString stringWithFormat:@"record %d is inside the message", record], nil);
        uint8_t header = raw[at];
        size_t typeLength = raw[at + 1];
        size_t payloadLength = raw[at + 2];
        size_t after = at + 3;
        if (header & 0x10) {
            after += 1;
        }
        check_named(after + typeLength + payloadLength <= chunkedBytes.length,
                     [NSString stringWithFormat:@"record %d is whole", record], nil);
        check_named((header & 0x01) != 0 ? record > 0 : record == 0,
                     [NSString stringWithFormat:@"record %d is %s", record, record == 0 ? "the first" : "a continuation"],
                     [NSString stringWithFormat:@"header 0x%02x", header]);
        check_named(typeLength == (record == 0 ? 1u : 0u),
                     [NSString stringWithFormat:@"record %d carries %s", record, record == 0 ? "the type" : "no type of its own"],
                     [NSString stringWithFormat:@"%lu", (unsigned long)typeLength]);
        check_named(raw[after + typeLength] == record,
                     [NSString stringWithFormat:@"record %d is numbered %d by its first payload byte", record, record],
                     [NSString stringWithFormat:@"0x%02x", raw[after + typeLength]]);
        at = after + typeLength + payloadLength;
    }
    check_named(at == chunkedBytes.length, @"and the three records are the whole message",
                 [NSString stringWithFormat:@"%lu of %lu", (unsigned long)at, (unsigned long)chunkedBytes.length]);
    NFCNDEFMessage *chunkedBack = [NFCNDEFMessage ndefMessageWithData:chunkedBytes];
    check_named([chunkedBack.records.firstObject.payload isEqualToData:ten], @"and the group reads back as the ten bytes it was",
                 [chunkedBack.records.firstObject.payload description]);

    NSMutableData *truncated = [URIVector() mutableCopy];
    [truncated appendBytes:(const unsigned char *)"\x09\x09\x09" length:3];
    NFCNDEFMessage *afterTruncation = [NFCNDEFMessage ndefMessageWithData:truncated];
    check_named(afterTruncation.records.count == 1, @"a record that does not add up ends the message rather than repairing it",
                 [NSString stringWithFormat:@"%lu records", (unsigned long)afterTruncation.records.count]);
    check_named([[NFCNDEFMessage ndefMessageWithData:chunkedBytes].records.firstObject.payload isEqualToData:ten],
                 @"a chunked group reads back as the one payload it was", nil);

    NFCNDEFMessage *archived = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:built]];
    check_named(archived.records.count == built.records.count, @"a message survives secure coding with its records",
                 [NSString stringWithFormat:@"%lu", (unsigned long)archived.records.count]);
    check_named([archived.records.firstObject.payload isEqualToData:textRecord.payload], @"and the payload with it",
                 [archived.records.firstObject.payload description]);

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures == 0 ? 0 : 1;
}
