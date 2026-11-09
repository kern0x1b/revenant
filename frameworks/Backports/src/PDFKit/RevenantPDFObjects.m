#import "RevenantPDFObjects.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

static const uint8_t kPasswordPadding[32] = {
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A};

@implementation RevenantPDFName

@synthesize value = _value;

+ (instancetype)name:(NSString *)value
{
    RevenantPDFName *name = [[RevenantPDFName alloc] init];
    name->_value = [value copy];
    return name;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    return [other isKindOfClass:[RevenantPDFName class]] && [_value isEqualToString:((RevenantPDFName *)other)->_value];
}

- (NSUInteger)hash
{
    return _value.hash;
}

@end

@implementation RevenantPDFReference

@synthesize number = _number;

+ (instancetype)referenceWithNumber:(NSUInteger)number
{
    RevenantPDFReference *reference = [[RevenantPDFReference alloc] init];
    reference->_number = number;
    return reference;
}

@end

@implementation RevenantPDFStream

@synthesize dictionary = _dictionary;
@synthesize data = _data;

+ (instancetype)streamWithDictionary:(NSDictionary<NSString *, id> *)dictionary data:(NSData *)data
{
    RevenantPDFStream *stream = [[RevenantPDFStream alloc] init];
    stream->_dictionary = [dictionary copy];
    stream->_data = [data copy];
    return stream;
}

+ (instancetype)deflatedStreamWithDictionary:(NSDictionary<NSString *, id> *)dictionary data:(NSData *)data
{
    NSData *deflated = RevenantPDFDeflate(data);
    if (deflated == nil || deflated.length >= data.length)
        return [self streamWithDictionary:dictionary data:data];
    NSMutableDictionary *entries = [dictionary mutableCopy];
    entries[@"Filter"] = [RevenantPDFName name:@"FlateDecode"];
    return [self streamWithDictionary:entries data:deflated];
}

@end

NSData *RevenantPDFDeflate(NSData *data)
{
    if (data.length > UINT32_MAX)
        return nil;
    uLongf capacity = compressBound((uLong)data.length);
    NSMutableData *out = [NSMutableData dataWithLength:capacity];
    if (compress2(out.mutableBytes, &capacity, data.bytes, (uLong)data.length, Z_DEFAULT_COMPRESSION) != Z_OK)
        return nil;
    out.length = capacity;
    return out;
}

NSString *RevenantPDFDateString(NSDate *date)
{
    time_t seconds = (time_t)floor([date timeIntervalSince1970]);
    struct tm parts;
    gmtime_r(&seconds, &parts);
    return [NSString stringWithFormat:@"D:%04d%02d%02d%02d%02d%02dZ00'00'", parts.tm_year + 1900, parts.tm_mon + 1,
                                      parts.tm_mday, parts.tm_hour, parts.tm_min, parts.tm_sec];
}

static BOOL revenantDigits(const char *bytes, NSUInteger length, NSUInteger *at, NSUInteger count, int *value)
{
    if (*at + count > length)
        return NO;
    int result = 0;
    for (NSUInteger i = 0; i < count; i++) {
        char c = bytes[*at + i];
        if (c < '0' || c > '9')
            return NO;
        result = result * 10 + (c - '0');
    }
    *at += count;
    *value = result;
    return YES;
}

NSDate *RevenantPDFDateFromString(NSString *string)
{
    const char *bytes = string.UTF8String;
    if (bytes == NULL)
        return nil;
    NSUInteger length = strlen(bytes);
    NSUInteger at = 0;
    if (length >= 2 && bytes[0] == 'D' && bytes[1] == ':')
        at = 2;
    int fields[6] = {0, 1, 1, 0, 0, 0};
    NSUInteger widths[6] = {4, 2, 2, 2, 2, 2};
    for (int i = 0; i < 6; i++) {
        int value = 0;
        if (!revenantDigits(bytes, length, &at, widths[i], &value)) {
            if (i == 0)
                return nil;
            break;
        }
        fields[i] = value;
    }
    NSInteger offset = 0;
    if (at < length && (bytes[at] == '+' || bytes[at] == '-')) {
        int sign = bytes[at] == '-' ? -1 : 1;
        at++;
        int hours = 0, minutes = 0;
        if (revenantDigits(bytes, length, &at, 2, &hours)) {
            if (at < length && bytes[at] == '\'')
                at++;
            revenantDigits(bytes, length, &at, 2, &minutes);
            offset = sign * (hours * 3600 + minutes * 60);
        }
    }
    struct tm parts;
    memset(&parts, 0, sizeof parts);
    parts.tm_year = fields[0] - 1900;
    parts.tm_mon = fields[1] - 1;
    parts.tm_mday = fields[2];
    parts.tm_hour = fields[3];
    parts.tm_min = fields[4];
    parts.tm_sec = fields[5];
    time_t seconds = timegm(&parts);
    if (seconds == (time_t)-1)
        return nil;
    return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)(seconds - offset)];
}

uint32_t RevenantPDFPermissionBits(NSUInteger accessPermissions)
{
    uint32_t bits = 0;
    if (accessPermissions & (1 << 0))
        bits |= 0x4;
    if (accessPermissions & (1 << 1))
        bits |= 0x4 | 0x800;
    if (accessPermissions & (1 << 2))
        bits |= 0x8;
    if (accessPermissions & (1 << 3))
        bits |= 0x400;
    if (accessPermissions & (1 << 4))
        bits |= 0x10;
    if (accessPermissions & (1 << 5))
        bits |= 0x200;
    if (accessPermissions & (1 << 6))
        bits |= 0x20;
    if (accessPermissions & (1 << 7))
        bits |= 0x100;
    return 0xFFFFF0C0u | bits;
}

@interface RevenantPDFEncryption : NSObject
@property (nonatomic, readonly) NSDictionary *dictionary;
@property (nonatomic, readonly) NSData *documentID;
- (instancetype)initWithOwnerPassword:(NSString *)owner
                         userPassword:(NSString *)user
                          permissions:(uint32_t)permissions
                           documentID:(NSData *)documentID;
- (NSData *)encrypt:(NSData *)data object:(NSUInteger)number;
@end

static NSData *revenantPaddedPassword(NSString *password)
{
    NSData *bytes = [password dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO] ?: [password dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *padded = [NSMutableData dataWithCapacity:32];
    [padded appendBytes:bytes.bytes length:MIN(bytes.length, 32)];
    [padded appendBytes:kPasswordPadding length:32 - padded.length];
    return padded;
}

static NSData *revenantRC4(NSData *key, NSData *data)
{
    NSMutableData *out = [NSMutableData dataWithLength:data.length];
    size_t moved = 0;
    CCCrypt(kCCEncrypt, kCCAlgorithmRC4, 0, key.bytes, key.length, NULL, data.bytes, data.length, out.mutableBytes, out.length, &moved);
    return out;
}

static NSData *revenantMD5(NSData *data)
{
    uint8_t digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof digest];
}

@implementation RevenantPDFEncryption {
    NSData *_key;
}

@synthesize dictionary = _dictionary;
@synthesize documentID = _documentID;

- (instancetype)initWithOwnerPassword:(NSString *)owner
                         userPassword:(NSString *)user
                          permissions:(uint32_t)permissions
                           documentID:(NSData *)documentID
{
    self = [super init];
    if (self == nil)
        return nil;
    _documentID = [documentID copy];
    NSData *userPadded = revenantPaddedPassword(user);

    NSData *ownerKey = revenantMD5(revenantPaddedPassword(owner.length > 0 ? owner : user));
    for (int i = 0; i < 50; i++)
        ownerKey = revenantMD5(ownerKey);
    ownerKey = [ownerKey subdataWithRange:NSMakeRange(0, 16)];
    NSData *ownerEntry = revenantRC4(ownerKey, userPadded);
    for (uint8_t round = 1; round <= 19; round++) {
        NSMutableData *roundKey = [ownerKey mutableCopy];
        uint8_t *bytes = roundKey.mutableBytes;
        for (NSUInteger i = 0; i < roundKey.length; i++)
            bytes[i] ^= round;
        ownerEntry = revenantRC4(roundKey, ownerEntry);
    }

    uint8_t flags[4] = {(uint8_t)permissions, (uint8_t)(permissions >> 8), (uint8_t)(permissions >> 16), (uint8_t)(permissions >> 24)};
    NSMutableData *keyInput = [NSMutableData dataWithData:userPadded];
    [keyInput appendData:ownerEntry];
    [keyInput appendBytes:flags length:4];
    [keyInput appendData:documentID];
    NSData *key = revenantMD5(keyInput);
    for (int i = 0; i < 50; i++)
        key = revenantMD5([key subdataWithRange:NSMakeRange(0, 16)]);
    _key = [key subdataWithRange:NSMakeRange(0, 16)];

    NSMutableData *userInput = [NSMutableData dataWithBytes:kPasswordPadding length:32];
    [userInput appendData:documentID];
    NSData *userEntry = revenantRC4(_key, revenantMD5(userInput));
    for (uint8_t round = 1; round <= 19; round++) {
        NSMutableData *roundKey = [_key mutableCopy];
        uint8_t *bytes = roundKey.mutableBytes;
        for (NSUInteger i = 0; i < roundKey.length; i++)
            bytes[i] ^= round;
        userEntry = revenantRC4(roundKey, userEntry);
    }
    NSMutableData *userValue = [userEntry mutableCopy];
    [userValue appendData:[NSMutableData dataWithLength:16]];

    _dictionary = @{
        @"Filter" : [RevenantPDFName name:@"Standard"],
        @"V" : @4,
        @"R" : @4,
        @"Length" : @128,
        @"P" : @((int32_t)permissions),
        @"O" : ownerEntry,
        @"U" : userValue,
        @"CF" : @{@"StdCF" : @{@"Type" : [RevenantPDFName name:@"CryptFilter"], @"CFM" : [RevenantPDFName name:@"AESV2"],
                               @"AuthEvent" : [RevenantPDFName name:@"DocOpen"], @"Length" : @16}},
        @"StmF" : [RevenantPDFName name:@"StdCF"],
        @"StrF" : [RevenantPDFName name:@"StdCF"],
    };
    return self;
}

- (NSData *)encrypt:(NSData *)data object:(NSUInteger)number
{
    uint8_t suffix[9] = {(uint8_t)number, (uint8_t)(number >> 8), (uint8_t)(number >> 16), 0, 0, 0x73, 0x41, 0x6C, 0x54};
    NSMutableData *input = [_key mutableCopy];
    [input appendBytes:suffix length:sizeof suffix];
    NSData *objectKey = revenantMD5(input);
    uint8_t iv[16];
    arc4random_buf(iv, sizeof iv);
    NSMutableData *out = [NSMutableData dataWithLength:16 + data.length + kCCBlockSizeAES128];
    memcpy(out.mutableBytes, iv, 16);
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding, objectKey.bytes, 16, iv, data.bytes,
                                     data.length, (uint8_t *)out.mutableBytes + 16, out.length - 16, &moved);
    if (status != kCCSuccess)
        return nil;
    out.length = 16 + moved;
    return out;
}

@end

static void revenantAppend(NSMutableData *out, const char *text)
{
    [out appendBytes:text length:strlen(text)];
}

static void revenantAppendReal(NSMutableData *out, double value)
{
    if (!isfinite(value))
        value = 0;
    char buffer[64];
    int length = snprintf(buffer, sizeof buffer, "%.6f", value);
    while (length > 0 && buffer[length - 1] == '0')
        length--;
    if (length > 0 && buffer[length - 1] == '.')
        length--;
    buffer[length] = 0;
    if (length == 0 || strcmp(buffer, "-0") == 0 || strcmp(buffer, "-") == 0) {
        revenantAppend(out, "0");
        return;
    }
    revenantAppend(out, buffer);
}

static void revenantAppendName(NSMutableData *out, NSString *name)
{
    NSData *bytes = [name dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
    [out appendBytes:"/" length:1];
    const uint8_t *raw = bytes.bytes;
    for (NSUInteger i = 0; i < bytes.length; i++) {
        uint8_t c = raw[i];
        if (c < 0x21 || c > 0x7E || strchr("()<>[]{}/%#", c) != NULL) {
            char escaped[4];
            snprintf(escaped, sizeof escaped, "#%02X", c);
            [out appendBytes:escaped length:3];
        } else {
            [out appendBytes:&c length:1];
        }
    }
}

static void revenantAppendHex(NSMutableData *out, NSData *data)
{
    static const char digits[] = "0123456789ABCDEF";
    [out appendBytes:"<" length:1];
    const uint8_t *raw = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        char pair[2] = {digits[raw[i] >> 4], digits[raw[i] & 15]};
        [out appendBytes:pair length:2];
    }
    [out appendBytes:">" length:1];
}

static NSData *revenantTextBytes(NSString *text, BOOL *ascii)
{
    BOOL plain = YES;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c < 0x20 || c > 0x7E) {
            plain = NO;
            break;
        }
    }
    *ascii = plain;
    if (plain)
        return [text dataUsingEncoding:NSASCIIStringEncoding];
    NSMutableData *bytes = [NSMutableData dataWithBytes:"\xFE\xFF" length:2];
    [bytes appendData:[text dataUsingEncoding:NSUTF16BigEndianStringEncoding]];
    return bytes;
}

static void revenantAppendObject(NSMutableData *out, id object, RevenantPDFEncryption *encryption, NSUInteger number);

static void revenantAppendString(NSMutableData *out, NSData *bytes, BOOL ascii, RevenantPDFEncryption *encryption, NSUInteger number)
{
    if (encryption != nil) {
        revenantAppendHex(out, [encryption encrypt:bytes object:number] ?: [NSData data]);
        return;
    }
    if (!ascii) {
        revenantAppendHex(out, bytes);
        return;
    }
    [out appendBytes:"(" length:1];
    const uint8_t *raw = bytes.bytes;
    for (NSUInteger i = 0; i < bytes.length; i++) {
        if (raw[i] == '(' || raw[i] == ')' || raw[i] == '\\')
            [out appendBytes:"\\" length:1];
        [out appendBytes:&raw[i] length:1];
    }
    [out appendBytes:")" length:1];
}

static void revenantAppendDictionary(NSMutableData *out, NSDictionary *dictionary, RevenantPDFEncryption *encryption, NSUInteger number)
{
    revenantAppend(out, "<<");
    for (NSString *key in [dictionary.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        revenantAppendName(out, key);
        revenantAppend(out, " ");
        revenantAppendObject(out, dictionary[key], encryption, number);
        revenantAppend(out, "\n");
    }
    revenantAppend(out, ">>");
}

static void revenantAppendObject(NSMutableData *out, id object, RevenantPDFEncryption *encryption, NSUInteger number)
{
    if (object == nil || object == [NSNull null]) {
        revenantAppend(out, "null");
    } else if ([object isKindOfClass:[RevenantPDFName class]]) {
        revenantAppendName(out, ((RevenantPDFName *)object).value);
    } else if ([object isKindOfClass:[RevenantPDFReference class]]) {
        char buffer[32];
        snprintf(buffer, sizeof buffer, "%lu 0 R", (unsigned long)((RevenantPDFReference *)object).number);
        revenantAppend(out, buffer);
    } else if ([object isKindOfClass:[NSNumber class]]) {
        CFTypeRef reference = (__bridge CFTypeRef)object;
        if (CFGetTypeID(reference) == CFBooleanGetTypeID()) {
            revenantAppend(out, [object boolValue] ? "true" : "false");
        } else if (CFNumberIsFloatType((CFNumberRef)reference)) {
            revenantAppendReal(out, [object doubleValue]);
        } else {
            char buffer[32];
            snprintf(buffer, sizeof buffer, "%lld", [object longLongValue]);
            revenantAppend(out, buffer);
        }
    } else if ([object isKindOfClass:[NSString class]]) {
        BOOL ascii = NO;
        revenantAppendString(out, revenantTextBytes(object, &ascii), ascii, encryption, number);
    } else if ([object isKindOfClass:[NSDate class]]) {
        BOOL ascii = NO;
        revenantAppendString(out, revenantTextBytes(RevenantPDFDateString(object), &ascii), ascii, encryption, number);
    } else if ([object isKindOfClass:[NSData class]]) {
        revenantAppendString(out, object, NO, encryption, number);
    } else if ([object isKindOfClass:[NSArray class]]) {
        revenantAppend(out, "[");
        BOOL first = YES;
        for (id element in (NSArray *)object) {
            if (!first)
                revenantAppend(out, " ");
            first = NO;
            revenantAppendObject(out, element, encryption, number);
        }
        revenantAppend(out, "]");
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        revenantAppendDictionary(out, object, encryption, number);
    }
}

static void revenantAppendStream(NSMutableData *out, RevenantPDFStream *stream, RevenantPDFEncryption *encryption, NSUInteger number)
{
    NSData *data = encryption != nil ? ([encryption encrypt:stream.data object:number] ?: [NSData data]) : stream.data;
    NSMutableDictionary *dictionary = [stream.dictionary mutableCopy];
    dictionary[@"Length"] = @(data.length);
    revenantAppendDictionary(out, dictionary, encryption, number);
    revenantAppend(out, "\nstream\n");
    [out appendData:data];
    revenantAppend(out, "\nendstream");
}

@implementation RevenantPDFWriter {
    NSMutableArray *_objects;
    RevenantPDFEncryption *_encryption;
    NSData *_documentID;
}

@dynamic objectCount;

- (instancetype)init
{
    return [self initEncryptedWithOwnerPassword:nil userPassword:nil permissions:0];
}

- (instancetype)initEncryptedWithOwnerPassword:(NSString *)owner userPassword:(NSString *)user permissions:(uint32_t)permissions
{
    self = [super init];
    if (self == nil)
        return nil;
    _objects = [NSMutableArray array];
    uint8_t identifier[16];
    arc4random_buf(identifier, sizeof identifier);
    _documentID = [NSData dataWithBytes:identifier length:sizeof identifier];
    if (owner.length > 0)
        _encryption = [[RevenantPDFEncryption alloc] initWithOwnerPassword:owner userPassword:user ?: @"" permissions:permissions
                                                                 documentID:_documentID];
    return self;
}

- (NSUInteger)objectCount
{
    return _objects.count;
}

- (RevenantPDFReference *)reserve
{
    [_objects addObject:[NSNull null]];
    return [RevenantPDFReference referenceWithNumber:_objects.count];
}

- (RevenantPDFReference *)add:(id)object
{
    RevenantPDFReference *reference = [self reserve];
    [self setObject:object forReference:reference];
    return reference;
}

- (void)setObject:(id)object forReference:(RevenantPDFReference *)reference
{
    _objects[reference.number - 1] = object;
}

- (RevenantPDFReference *)addCatalogWithPages:(RevenantPDFReference *)pages kids:(NSArray<RevenantPDFReference *> *)kids
{
    [self setObject:@{@"Type" : [RevenantPDFName name:@"Pages"], @"Kids" : kids, @"Count" : @(kids.count)} forReference:pages];
    return [self add:@{@"Type" : [RevenantPDFName name:@"Catalog"], @"Pages" : pages}];
}

- (NSData *)dataWithRoot:(RevenantPDFReference *)root info:(RevenantPDFReference *)info
{
    NSMutableData *out = [NSMutableData data];
    revenantAppend(out, _encryption != nil ? "%PDF-1.6\n" : "%PDF-1.4\n");
    [out appendBytes:"%\xE2\xE3\xCF\xD3\n" length:6];
    NSUInteger count = _objects.count;
    RevenantPDFReference *encryptReference = nil;
    NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:count + 1];
    NSMutableArray *objects = [_objects mutableCopy];
    if (_encryption != nil) {
        [objects addObject:_encryption.dictionary];
        encryptReference = [RevenantPDFReference referenceWithNumber:objects.count];
    }
    for (NSUInteger index = 0; index < objects.count; index++) {
        [offsets addObject:@(out.length)];
        NSUInteger number = index + 1;
        char header[32];
        snprintf(header, sizeof header, "%lu 0 obj\n", (unsigned long)number);
        revenantAppend(out, header);
        id object = objects[index];
        RevenantPDFEncryption *encryption = (_encryption != nil && object != _encryption.dictionary) ? _encryption : nil;
        if ([object isKindOfClass:[RevenantPDFStream class]])
            revenantAppendStream(out, object, encryption, number);
        else
            revenantAppendObject(out, object, encryption, number);
        revenantAppend(out, "\nendobj\n");
    }
    NSUInteger xref = out.length;
    char line[64];
    snprintf(line, sizeof line, "xref\n0 %lu\n", (unsigned long)objects.count + 1);
    revenantAppend(out, line);
    revenantAppend(out, "0000000000 65535 f \n");
    for (NSNumber *offset in offsets) {
        snprintf(line, sizeof line, "%010lu 00000 n \n", (unsigned long)offset.unsignedLongValue);
        revenantAppend(out, line);
    }
    NSMutableDictionary *trailer = [NSMutableDictionary dictionary];
    trailer[@"Size"] = @(objects.count + 1);
    trailer[@"Root"] = root;
    if (info != nil)
        trailer[@"Info"] = info;
    if (encryptReference != nil)
        trailer[@"Encrypt"] = encryptReference;
    revenantAppend(out, "trailer\n<<");
    for (NSString *key in [trailer.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        revenantAppendName(out, key);
        revenantAppend(out, " ");
        revenantAppendObject(out, trailer[key], nil, 0);
        revenantAppend(out, "\n");
    }
    revenantAppend(out, "/ID [");
    revenantAppendHex(out, _documentID);
    revenantAppend(out, " ");
    revenantAppendHex(out, _documentID);
    revenantAppend(out, "]>>\n");
    snprintf(line, sizeof line, "startxref\n%lu\n%%%%EOF\n", (unsigned long)xref);
    revenantAppend(out, line);
    return out;
}

@end
