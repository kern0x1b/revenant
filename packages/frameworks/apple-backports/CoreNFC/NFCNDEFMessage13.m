#import <CoreNFC/CoreNFC.h>
#import "RevenantNDEF.h"

static NSData *RevenantNDEFRTD(const char *rtd, size_t length)
{
    return [NSData dataWithBytes:rtd length:length];
}

static NSData *RevenantNDEFURIRTD(void)
{
    static NSData *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ type = RevenantNDEFRTD("U", 1); });
    return type;
}

static NSData *RevenantNDEFTextRTD(void)
{
    static NSData *type;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ type = RevenantNDEFRTD("T", 1); });
    return type;
}

@interface NFCNDEFPayload (RevenantRecord)

- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload;
- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload chunkSize:(size_t)chunkSize;
- (size_t)revenantChunkSize;

@end

@implementation NFCNDEFPayload (RevenantRecord)

- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload
{
    self = [super init];
    if (self) {
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
        [self setValue:[NSData dataWithBytes:&chunkSize length:sizeof chunkSize] forKey:@"chunkSize"];
    }
    return self;
}

- (size_t)revenantChunkSize
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

static uint8_t RevenantNDEFPrefixIndex(NSString *uri, NSUInteger *rest)
{
    uint8_t table = 0x00;
    *rest = uri.length;
    for (NSUInteger index = 1; index < RevenantNDEFURIPrefixCount; index++) {
        NSString *prefix = @(RevenantNDEFURIPrefixes[index]);
        if (prefix.length && [uri hasPrefix:prefix]) {
            table = (uint8_t)index;
            *rest = uri.length - prefix.length;
        }
    }
    return table;
}

static NSData *RevenantNDEFURIPayloadData(NSString *uri)
{
    NSUInteger rest = 0;
    uint8_t table = RevenantNDEFPrefixIndex(uri, &rest);
    NSMutableData *bytes = [NSMutableData dataWithBytes:&table length:1];
    const char *tail = uri.UTF8String;
    if (tail) {
        [bytes appendBytes:tail + (uri.length - rest) length:strlen(tail) - (uri.length - rest)];
    }
    return bytes;
}

+ (instancetype)revenantURIPayload:(NSString *)uri
{
    if (!uri) {
        return nil;
    }
    return [[self alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown type:RevenantNDEFURIRTD() identifier:nil
                                payload:RevenantNDEFURIPayloadData(uri)];
}

+ (instancetype)wellKnownTypeURIPayloadWithString:(NSString *)uri
{
    return [self revenantURIPayload:uri];
}

+ (instancetype)wellKnownTypeURIPayloadWithURL:(NSURL *)url
{
    return [self revenantURIPayload:url.absoluteString];
}

- (NSURL *)wellKnownTypeURIPayload
{
    if (self.typeNameFormat != NFCTypeNameFormatNFCWellKnown || ![self.type isEqualToData:RevenantNDEFURIRTD()]
        || self.payload.length < 1) {
        return nil;
    }
    const uint8_t *bytes = self.payload.bytes;
    if (bytes[0] >= RevenantNDEFURIPrefixCount) {
        return nil;
    }
    NSString *text = [[NSString alloc] initWithBytes:bytes + 1 length:self.payload.length - 1 encoding:NSUTF8StringEncoding];
    if (!text) {
        return nil;
    }
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", @(RevenantNDEFURIPrefixes[bytes[0]]), text]];
}

static NSData *RevenantNDEFTextPayloadData(NSString *text, NSString *language)
{
    const char *code = language.UTF8String ?: "en";
    size_t codeLength = strlen(code);
    if (codeLength == 0 || codeLength > RevenantNDEFTextLanguageLengthMask) {
        return nil;
    }
    uint8_t status = (uint8_t)(codeLength & RevenantNDEFTextLanguageLengthMask);
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
    NSData *payload = RevenantNDEFTextPayloadData(text, language);
    if (!payload) {
        return nil;
    }
    return [[self alloc] initWithFormat:NFCTypeNameFormatNFCWellKnown type:RevenantNDEFTextRTD() identifier:nil payload:payload];
}

+ (instancetype)wellKnowTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale
{
    return [self wellKnownTypeTextPayloadWithString:text locale:locale];
}

- (NSString *)revenantTextWithLocale:(NSLocale *__autoreleasing _Nullable * _Nonnull)outLocale
{
    if (self.typeNameFormat != NFCTypeNameFormatNFCWellKnown || ![self.type isEqualToData:RevenantNDEFTextRTD()]
        || self.payload.length < 1) {
        return nil;
    }
    const uint8_t *bytes = self.payload.bytes;
    size_t codeLength = bytes[0] & RevenantNDEFTextLanguageLengthMask;
    if (self.payload.length < 1 + codeLength) {
        return nil;
    }
    NSStringEncoding encoding = (bytes[0] & RevenantNDEFTextUTF16) ? NSUTF16StringEncoding : NSUTF8StringEncoding;
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
    return [self revenantTextWithLocale:locale];
}

@end

@interface NFCNDEFMessage (RevenantRecord)

- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records;

@end

@implementation NFCNDEFMessage (RevenantRecord)

static size_t RevenantNDEFRender(NFCNDEFPayload *payload, BOOL first, BOOL last, BOOL continuation,
                               uint8_t marker, BOOL withMarker, NSMutableData *into)
{
    RevenantNDEFRecord record;
    memset(&record, 0, sizeof record);
    record.format = payload.typeNameFormat;
    record.first = first;
    record.last = last;
    record.continuation = continuation;
    record.hasIdentifierField = payload.identifier.length != 0;
    if (!continuation) {
        record.typeLength = MIN(payload.type.length, (NSUInteger)RevenantNDEFMaxTypeLength);
        if (record.typeLength) {
            memcpy(record.type, payload.type.bytes, record.typeLength);
        }
        record.identifierLength = MIN(payload.identifier.length, (NSUInteger)RevenantNDEFMaxIDLength);
        if (record.identifierLength) {
            memcpy(record.identifier, payload.identifier.bytes, record.identifierLength);
        }
    }
    const uint8_t *body = payload.payload.bytes;
    size_t payloadLength = payload.payload.length;
    if (withMarker) {
        ++payloadLength;
    }
    record.payload = body;
    record.payloadLength = payloadLength;
    size_t length = RevenantNDEFRecordLength(&record);
    if (length == 0) {
        return 0;
    }
    uint8_t *out = calloc(1, length);
    if (!out) {
        return 0;
    }
    if (RevenantNDEFRecordEncode(&record, out, length) != length) {
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

- (void)revenantAppendPayload:(NFCNDEFPayload *)payload into:(NSMutableData *)into first:(BOOL *)first last:(BOOL)last
{
    size_t chunkSize = [payload revenantChunkSize];
    if (chunkSize == 0 || payload.payload.length <= chunkSize) {
        RevenantNDEFRender(payload, *first, last, NO, 0, NO, into);
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
        RevenantNDEFRender(chunk, *first, ends, !starts, marker, YES, into);
        *first = NO;
        offset += take;
        ++marker;
    }
}

- (NSData *)revenantEncodedRecords
{
    NSData *already = [self valueForKey:@"revenantEncoded"];
    if (already) {
        return already;
    }
    NSMutableData *bytes = [NSMutableData data];
    BOOL first = YES;
    for (NFCNDEFPayload *payload in self.records) {
        [self revenantAppendPayload:payload into:bytes first:&first last:payload == self.records.lastObject];
    }
    [self setValue:bytes forKey:@"revenantEncoded"];
    return bytes;
}

- (NSUInteger)length
{
    return [self revenantEncodedRecords].length;
}

NSData *RevenantNDEFEncodedRecords(NFCNDEFMessage *message)
{
    return [(id)message performSelector:@selector(revenantEncodedRecords)];
}

- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records
{
    self = [super init];
    if (self) {
        [self setValue:records forKey:@"records"];
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
        RevenantNDEFRecord record;
        memset(&record, 0, sizeof record);
        size_t used = RevenantNDEFRecordDecode(bytes + offset, length - offset, &record);
        if (used == 0) {
            break;
        }
        offset += used;
        if (record.continuation) {
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
        NSData *identifier = record.hasIdentifierField
            ? [NSData dataWithBytes:record.identifier length:record.identifierLength] : nil;
        NSMutableData *payload = [NSMutableData dataWithBytes:record.payload length:record.payloadLength];
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
