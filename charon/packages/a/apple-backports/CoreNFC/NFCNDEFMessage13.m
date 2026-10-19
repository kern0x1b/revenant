#import <CoreNFC/CoreNFC.h>
#import "CharonNDEF.h"

// The members iOS 13.0 added to NFCNDEFPayload and NFCNDEFMessage: the initialisers that take a
// record's fields, the chunked one, the well-known URI and text helpers, +ndefMessageWithData: and
// -length. They are a separate object because an object carries the API of one release.
//
// The encoding and the parsing are the record shape of CharonNDEF.h, the NFC Forum NDEF Technical
// Specification: the header byte with MB, ME, SR, IL, TNF and CF, a one-byte type length, a one- or
// four-byte payload length, a one-byte ID length, then the type, the ID and the payload. A record that
// does not add up is refused, never repaired.
//
// **The buffer the encoder writes into is a parameter, not a property.** A category cannot reach the
// 11.0 object's own ivar, so the one that reads the bytes back does it through the property of the
// class extension - and an append that *fetched* the buffer through that property would be the encoder
// calling the builder that called the append. The builder owns the buffer, the append is handed it.

static NSData *CharonNDEFRTD(const char *rtd, size_t length)
{
    return [NSData dataWithBytes:rtd length:length];
}

// The two well-known types this file builds by name: the URI RTD "U" and the text RTD "T".
static NSData *CharonNDEFURIRTD(void)
{
    static NSData *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ type = CharonNDEFRTD("U", 1); });
    return type;
}

static NSData *CharonNDEFTextRTD(void)
{
    static NSData *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ type = CharonNDEFRTD("T", 1); });
    return type;
}

@interface NFCNDEFPayload (CharonRecord)

- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload;
- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload chunkSize:(size_t)chunkSize;
- (size_t)charonChunkSize;

@end

@implementation NFCNDEFPayload (CharonRecord)

- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload
{
    self = [super init];
    if (self) {
        // The class's own setters, because a category cannot reach the class's ivars.
        self.typeNameFormat = format;
        self.type = type;
        self.identifier = identifier;
        self.payload = payload;
    }
    return self;
}

- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload chunkSize:(size_t)chunkSize
{
    self = [self initWithFormat:format type:type identifier:identifier payload:payload];
    if (self && chunkSize > 0) {
        // A chunk size of zero, or none at all, means the payload is not chunked, and the port keeps
        // that as no chunk size rather than as one of zero.
        [self setValue:[NSData dataWithBytes:&chunkSize length:sizeof chunkSize] forKey:@"chunkSize"];
    }
    return self;
}

- (size_t)charonChunkSize
{
    NSData *size = [self valueForKey:@"chunkSize"];
    return size ? *(const size_t *)size.bytes : 0;
}

@end

@interface NFCNDEFPayload (ConvenienceHelpers)

- (NSURL *)wellKnownTypeURIPayload;
- (NSString *)wellKnownTypeTextPayloadWithLocale:(NSLocale *__autoreleasing * _Nonnull)locale;

@end

@implementation NFCNDEFPayload (ConvenienceHelpers)

// The prefix byte of a URI payload is the index of the longest entry of the URI RTD's table the URI
// begins with, which is the specification's own rule; index 0 is the empty prefix and is what a URI
// with none of them gets.
static uint8_t CharonNDEFPrefixIndex(NSString *uri, NSUInteger *rest)
{
    uint8_t table = 0x00;
    *rest = uri.length;
    for (NSUInteger index = 1; index < CharonNDEFURIPrefixCount; index++) {
        NSString *prefix = @(CharonNDEFURIPrefixes[index]);
        if (prefix.length && [uri hasPrefix:prefix]) {
            table = (uint8_t)index;
            *rest = uri.length - prefix.length;
        }
    }
    return table;
}

static NSData *CharonNDEFURIPayloadData(NSString *uri)
{
    NSUInteger rest = 0;
    uint8_t table = CharonNDEFPrefixIndex(uri, &rest);
    NSMutableData *bytes = [NSMutableData dataWithBytes:&table length:1];
    const char *tail = uri.UTF8String;
    if (tail) {
        [bytes appendBytes:tail + (uri.length - rest) length:strlen(tail) - (uri.length - rest)];
    }
    return bytes;
}

+ (instancetype)charonURIPayload:(NSString *)uri
{
    if (!uri) {
        return nil;
    }
    return [[self alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown type:CharonNDEFURIRTD() identifier:nil
                                payload:CharonNDEFURIPayloadData(uri)];
}

+ (instancetype)wellKnownTypeURIPayloadWithString:(NSString *)uri
{
    return [self charonURIPayload:uri];
}

+ (instancetype)wellKnownTypeURIPayloadWithURL:(NSURL *)url
{
    return [self charonURIPayload:url.absoluteString];
}

- (NSURL *)wellKnownTypeURIPayload
{
    if (self.typeNameFormat != NFCTypeNameFormatNFCWellKnown || ![self.type isEqualToData:CharonNDEFURIRTD()]
        || self.payload.length < 1) {
        return nil;
    }
    const uint8_t *bytes = self.payload.bytes;
    if (bytes[0] >= CharonNDEFURIPrefixCount) {
        return nil;
    }
    NSString *text = [[NSString alloc] initWithBytes:bytes + 1 length:self.payload.length - 1 encoding:NSUTF8StringEncoding];
    if (!text) {
        return nil;
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", @(CharonNDEFURIPrefixes[bytes[0]]), text]];
}

// The text RTD: the status byte carries the encoding in its top bit and the length of the language code
// in its low six, and the text follows the code. The port writes UTF-8 for every language, and its
// status byte says so; facts/CoreNFC/NDEF.md says why and what that costs.
static NSData *CharonNDEFTextPayloadData(NSString *text, NSString *language)
{
    const char *code = language.UTF8String ?: "en";
    size_t codeLength = strlen(code);
    if (codeLength == 0 || codeLength > CharonNDEFTextLanguageLengthMask) {
        return nil;
    }
    uint8_t status = (uint8_t)(codeLength & CharonNDEFTextLanguageLengthMask);
    NSMutableData *bytes = [NSMutableData dataWithBytes:&status length:1];
    [bytes appendBytes:code length:codeLength];
    [bytes appendData:[text dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data]];
    return bytes;
}

+ (instancetype)wellKnownTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale
{
    if (!text) {
        return nil;
    }
    NSString *language = [locale objectForKey:locale.localeIdentifier ?: @"en"];
    NSData *payload = CharonNDEFTextPayloadData(text, language);
    if (!payload) {
        return nil;
    }
    return [[self alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown type:CharonNDEFTextRTD() identifier:nil payload:payload];
}

+ (instancetype)wellKnowTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale
{
    // The spelling Apple deprecated in the release that replaced it. Carried, so code written against
    // either name links, and both answer the same.
    return [self wellKnownTypeTextPayloadWithString:text locale:locale];
}

- (NSString *)charonTextWithLocale:(NSLocale *__autoreleasing _Nullable * _Nonnull)outLocale
{
    if (self.typeNameFormat != NFCTypeNameFormatNFCWellKnown || ![self.type isEqualToData:CharonNDEFTextRTD()]
        || self.payload.length < 1) {
        return nil;
    }
    const uint8_t *bytes = self.payload.bytes;
    size_t codeLength = bytes[0] & CharonNDEFTextLanguageLengthMask;
    if (self.payload.length < 1 + codeLength) {
        return nil;
    }
    NSStringEncoding encoding = (bytes[0] & CharonNDEFTextUTF16) ? NSUTF16StringEncoding : NSUTF8StringEncoding;
    if (outLocale) {
        NSString *code = codeLength ? [[NSString alloc] initWithBytes:bytes + 1 length:codeLength
                                        encoding:NSASCIIStringEncoding] : nil;
        *outLocale = code ? [NSLocale localeWithLocaleIdentifier:code] : nil;
    }
    return [[NSString alloc] initWithBytes:bytes + 1 + codeLength length:self.payload.length - 1 - codeLength
                                 encoding:encoding];
}

- (NSString *)wellKnownTypeTextPayloadWithLocale:(NSLocale *__autoreleasing * _Nonnull)locale
{
    return [self charonTextWithLocale:locale];
}

@end

@interface NFCNDEFMessage (CharonRecord)

- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records;

@end

@implementation NFCNDEFMessage (CharonRecord)

// One record, written into `into`. `marker` is the chunk marker and is placed as the first byte of the
// payload, which is where a chunked payload's marker belongs; a continuation carries no type and no ID
// of its own, which is what the CF flag is for.
static size_t CharonNDEFRender(NFCNDEFPayload *payload, BOOL first, BOOL last, BOOL continuation,
                               uint8_t marker, BOOL withMarker, NSMutableData *into)
{
    CharonNDEFRecord record;
    memset(&record, 0, sizeof record);
    record.format = payload.typeNameFormat;
    record.first = first;
    record.last = last;
    record.continuation = continuation;
    // An empty identifier is written with no ID field, as the host writes it (tests/backports/host/nfc-activity).
    record.hasIdentifierField = payload.identifier.length != 0;
    if (!continuation) {
        record.typeLength = MIN(payload.type.length, (NSUInteger)CharonNDEFMaxTypeLength);
        if (record.typeLength) {
            memcpy(record.type, payload.type.bytes, record.typeLength);
        }
        record.identifierLength = MIN(payload.identifier.length, (NSUInteger)CharonNDEFMaxIDLength);
        if (record.identifierLength) {
            memcpy(record.identifier, payload.identifier.bytes, record.identifierLength);
        }
    }
    const uint8_t *body = payload.payload.bytes;
    size_t payloadLength = payload.payload.length;
    if (withMarker) {
        ++payloadLength;   // the marker is the first byte of a chunked payload
    }
    record.payload = body;
    record.payloadLength = payloadLength;
    size_t length = CharonNDEFRecordLength(&record);
    if (length == 0) {
        return 0;
    }
    uint8_t *out = calloc(1, length);
    if (!out) {
        return 0;
    }
    if (CharonNDEFRecordEncode(&record, out, length) != length) {
        free(out);
        return 0;
    }
    if (withMarker) {
        memmove(out + length - record.payloadLength + 1, out + length - record.payloadLength, record.payloadLength - 1);
        out[length - record.payloadLength] = marker;
    }
    [into appendBytes:out length:length];
    free(out);
    return length;
}

// The records one payload expands into: itself, and one continuation per further chunk.
- (void)charonAppendPayload:(NFCNDEFPayload *)payload into:(NSMutableData *)into first:(BOOL *)first last:(BOOL)last
{
    size_t chunkSize = [payload charonChunkSize];
    if (chunkSize == 0 || payload.payload.length <= chunkSize) {
        CharonNDEFRender(payload, *first, last, NO, 0, NO, into);
        *first = NO;
        return;
    }
    size_t offset = 0;
    uint8_t marker = 0x00;
    while (offset < payload.payload.length) {
        size_t take = payload.payload.length - offset;
        if (take > chunkSize) {
            take = chunkSize;
        }
        NFCNDEFPayload *chunk = [[NFCNDEFPayload alloc] initWithFormat:payload.typeNameFormat type:payload.type
                                                             identifier:payload.identifier
                                                                payload:[payload.payload subdataWithRange:NSMakeRange(offset, take)]];
        BOOL starts = marker == 0x00;
        BOOL ends = offset + take >= payload.payload.length;
        // The marker is written here and nowhere else: the payload object carries the bytes of the
        // chunk and not the marker, the renderer puts the marker as the first byte of the payload, and
        // the parser reads that byte back. A chunk after the first has no type and no ID of its own,
        // which is what the CF flag is for.
        CharonNDEFRender(chunk, *first, ends, !starts, marker, YES, into);
        *first = NO;
        offset += take;
        ++marker;
    }
}

// The message's own bytes, made once and kept: -length is what they weigh, and +ndefMessageWithData: is
// the other direction.
- (NSData *)charonEncodedRecords
{
    NSData *already = [self valueForKey:@"charonEncoded"];
    if (already) {
        return already;
    }
    NSMutableData *bytes = [NSMutableData data];
    BOOL first = YES;
    for (NFCNDEFPayload *payload in self.records) {
        [self charonAppendPayload:payload into:bytes first:&first last:payload == self.records.lastObject];
    }
    [self setValue:bytes forKey:@"charonEncoded"];
    return bytes;
}

- (NSUInteger)length
{
    return [self charonEncodedRecords].length;
}

// The bytes a message encodes to. KVC would stop at the class extension's own getter, which answers
// nothing before the first encoding, so the private method is called here and the function is what the
// port's own header declares for it.
NSData *CharonNDEFEncodedRecords(NFCNDEFMessage *message)
{
    return [(id)message performSelector:@selector(charonEncodedRecords)];
}

- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records
{
    self = [super init];
    if (self) {
        [self setValue:records forKey:@"records"];   // the class's own property, which a category cannot reach as an ivar
    }
    return self;
}

+ (instancetype)ndefMessageWithData:(NSData *)data
{
    if (!data) {
        return nil;
    }
    const uint8_t *bytes = data.bytes;
    size_t length = data.length;
    NSMutableArray<NFCNDEFPayload *> *records = [NSMutableArray array];
    size_t offset = 0;
    NSData *groupType = nil;
    NFCTypeNameFormat groupFormat = NFCTypeNameFormatEmpty;
    NSData *groupIdentifier = nil;
    NSMutableData *groupPayload = nil;
    uint8_t expected = 1;
    while (offset < length) {
        CharonNDEFRecord record;
        memset(&record, 0, sizeof record);
        size_t used = CharonNDEFRecordDecode(bytes + offset, length - offset, &record);
        if (used == 0) {
            // A record that does not add up ends the message: what was read is a message, and the rest
            // is not one. Nothing is repaired and nothing is guessed at.
            break;
        }
        offset += used;
        if (record.continuation) {
            // A continuation belongs to the group before it and says which chunk it is, so a
            // continuation out of order, or without a group, is not a message this parser will answer.
            if (!groupPayload || record.payloadLength < 1 || record.payload[0] != expected) {
                return nil;
            }
            [groupPayload appendBytes:record.payload + 1 length:record.payloadLength - 1];
            ++expected;
            if (record.last) {
                [records addObject:[[NFCNDEFPayload alloc] initWithFormat:groupFormat type:groupType
                                                             identifier:groupIdentifier payload:groupPayload]];
                groupPayload = nil;
            }
            continue;
        }
        NSData *type = [NSData dataWithBytes:record.type length:record.typeLength];
        // No ID field at all is nil, not an empty data: an empty one would make the encoder write the
        // field back and the round trip would weigh a byte more than the bytes it was given.
        NSData *identifier = record.hasIdentifierField
            ? [NSData dataWithBytes:record.identifier length:record.identifierLength] : nil;
        NSMutableData *payload = [NSMutableData dataWithBytes:record.payload length:record.payloadLength];
        // A record whose payload begins with the zero marker opens a chunked group, which the
        // specification spells as a well-known record with the marker and continuations after it.
        BOOL chunked = record.format == NFCTypeNameFormatNFCWellKnown && record.payloadLength >= 1
            && record.payload[0] == 0x00;
        if (chunked) {
            [payload replaceBytesInRange:NSMakeRange(0, 1) withBytes:NULL length:0];
            groupType = type;
            groupFormat = (NFCTypeNameFormat)record.format;
            groupIdentifier = identifier;
            groupPayload = payload;
            expected = 1;
            if (record.last) {
                [records addObject:[[NFCNDEFPayload alloc] initWithFormat:groupFormat type:groupType
                                                             identifier:groupIdentifier payload:groupPayload]];
                groupPayload = nil;
            }
            continue;
        }
        [records addObject:[[NFCNDEFPayload alloc] initWithFormat:(NFCTypeNameFormat)record.format type:type
                                                     identifier:identifier payload:payload]];
    }
    return [[self alloc] initWithNDEFRecords:records];
}

@end
