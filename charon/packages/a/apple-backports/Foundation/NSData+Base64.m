#import <Foundation/Foundation.h>

static const char charon_base64_alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

enum {
    CharonBase64Unknown = 0xFF,
    CharonBase64Padding = 0xFE
};

static NSUInteger charon_base64_line_length(NSDataBase64EncodingOptions options)
{
    BOOL short64 = (options & NSDataBase64Encoding64CharacterLineLength) != 0;
    BOOL long76 = (options & NSDataBase64Encoding76CharacterLineLength) != 0;
    if (short64 == long76)
        return 0;
    return short64 ? 64 : 76;
}

static void charon_base64_fail_allocation(id data, SEL selector, NSUInteger length)
{
    [NSException raise:NSMallocException format:@"*** -[%@ %@]: unable to allocate memory for length (%lu)", [data class], NSStringFromSelector(selector), (unsigned long)length];
}

static char *charon_base64_encode(NSData *data, NSDataBase64EncodingOptions options, SEL selector, NSUInteger *encodedLength)
{
    NSUInteger length = data.length;
    const unsigned char *bytes = data.bytes;
    NSUInteger groups = length / 3 + (length % 3 ? 1 : 0);
    NSUInteger lineLength = charon_base64_line_length(options);
    BOOL carriageReturn = (options & NSDataBase64EncodingEndLineWithCarriageReturn) != 0;
    BOOL lineFeed = (options & NSDataBase64EncodingEndLineWithLineFeed) != 0;
    if (!carriageReturn && !lineFeed)
        carriageReturn = lineFeed = YES;
    NSUInteger endingLength = (carriageReturn ? 1 : 0) + (lineFeed ? 1 : 0);
    if (groups > (NSUIntegerMax - 1) / 4)
        charon_base64_fail_allocation(data, selector, length);
    NSUInteger characters = groups * 4;
    NSUInteger breaks = lineLength && characters ? (characters - 1) / lineLength : 0;
    if (breaks > (NSUIntegerMax - 1 - characters) / endingLength)
        charon_base64_fail_allocation(data, selector, length);
    NSUInteger total = characters + breaks * endingLength;
    char *output = malloc(total ? total : 1);
    if (!output)
        charon_base64_fail_allocation(data, selector, total);
    NSUInteger written = 0, line = 0;
    for (NSUInteger index = 0; index < length; index += 3) {
        NSUInteger remaining = length - index;
        uint32_t value = (uint32_t)bytes[index] << 16;
        if (remaining > 1)
            value |= (uint32_t)bytes[index + 1] << 8;
        if (remaining > 2)
            value |= bytes[index + 2];
        char group[4] = {
            charon_base64_alphabet[(value >> 18) & 0x3F],
            charon_base64_alphabet[(value >> 12) & 0x3F],
            remaining > 1 ? charon_base64_alphabet[(value >> 6) & 0x3F] : '=',
            remaining > 2 ? charon_base64_alphabet[value & 0x3F] : '='
        };
        for (int position = 0; position < 4; position++) {
            if (lineLength && line == lineLength) {
                if (carriageReturn)
                    output[written++] = '\r';
                if (lineFeed)
                    output[written++] = '\n';
                line = 0;
            }
            output[written++] = group[position];
            line++;
        }
    }
    *encodedLength = written;
    return output;
}

static unsigned char *charon_base64_decode(const unsigned char *input, NSUInteger length, NSDataBase64DecodingOptions options, NSUInteger *decodedLength)
{
    static unsigned char table[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        memset(table, CharonBase64Unknown, sizeof table);
        for (unsigned char value = 0; value < 64; value++)
            table[(unsigned char)charon_base64_alphabet[value]] = value;
        table['='] = CharonBase64Padding;
    });
    BOOL ignoreUnknown = (options & NSDataBase64DecodingIgnoreUnknownCharacters) != 0;
    unsigned char *output = malloc(length / 4 * 3 + 3);
    if (!output)
        return NULL;
    NSUInteger written = 0, count = 0, padding = 0, index = 0;
    uint32_t accumulated = 0;
    for (; index < length; index++) {
        unsigned char value = table[input[index]];
        if (value == CharonBase64Unknown) {
            if (ignoreUnknown)
                continue;
            free(output);
            return NULL;
        }
        if (value == CharonBase64Padding) {
            padding++;
            value = 0;
        } else if (padding && !ignoreUnknown) {
            free(output);
            return NULL;
        }
        accumulated = (accumulated << 6) + value;
        if (++count < 4)
            continue;
        if (padding == 3) {
            free(output);
            return NULL;
        }
        BOOL last = YES;
        for (NSUInteger ahead = index + 1; padding && ahead < length && last; ahead++) {
            unsigned char next = table[input[ahead]];
            last = next == CharonBase64Padding || (ignoreUnknown && next == CharonBase64Unknown);
        }
        NSUInteger bytes = !last || !padding ? 3 : padding == 1 ? 2 : 1;
        output[written++] = (accumulated >> 16) & 0xFF;
        if (bytes > 1)
            output[written++] = (accumulated >> 8) & 0xFF;
        if (bytes > 2)
            output[written++] = accumulated & 0xFF;
        count = 0;
        if (padding && !ignoreUnknown)
            break;
        padding = 0;
    }
    for (index++; index < length && !ignoreUnknown; index++) {
        if (table[input[index]] != CharonBase64Padding) {
            free(output);
            return NULL;
        }
    }
    if (count) {
        free(output);
        return NULL;
    }
    *decodedLength = written;
    return output;
}

static unsigned char *charon_base64_decode_string(NSString *string, NSDataBase64DecodingOptions options, NSUInteger *decodedLength)
{
    NSUInteger length = string.length;
    unsigned char *narrow = malloc(length ? length : 1);
    unichar *wide = malloc((length ? length : 1) * sizeof(unichar));
    if (!narrow || !wide) {
        free(narrow);
        free(wide);
        return NULL;
    }
    [string getCharacters:wide range:NSMakeRange(0, length)];
    for (NSUInteger index = 0; index < length; index++)
        narrow[index] = wide[index] < 0x80 ? (unsigned char)wide[index] : CharonBase64Unknown;
    free(wide);
    unsigned char *decoded = charon_base64_decode(narrow, length, options, decodedLength);
    free(narrow);
    return decoded;
}

static void charon_base64_require(id argument, id data, SEL selector, NSString *what)
{
    if (!argument)
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ %@]: nil %@ argument", [data class], NSStringFromSelector(selector), what];
}

@implementation NSData (CharonBase64)

- (instancetype)initWithBase64EncodedString:(NSString *)base64String options:(NSDataBase64DecodingOptions)options
{
    charon_base64_require(base64String, self, _cmd, @"string");
    NSUInteger length = 0;
    unsigned char *decoded = charon_base64_decode_string(base64String, options, &length);
    if (!decoded)
        return nil;
    if (!length) {
        free(decoded);
        return [self initWithBytes:NULL length:0];
    }
    return [self initWithBytesNoCopy:decoded length:length freeWhenDone:YES];
}

- (NSString *)base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)options
{
    NSUInteger length = 0;
    char *encoded = charon_base64_encode(self, options, _cmd, &length);
    if (!length) {
        free(encoded);
        return @"";
    }
    return [[NSString alloc] initWithBytesNoCopy:encoded length:length encoding:NSASCIIStringEncoding freeWhenDone:YES];
}

- (instancetype)initWithBase64EncodedData:(NSData *)base64Data options:(NSDataBase64DecodingOptions)options
{
    charon_base64_require(base64Data, self, _cmd, @"data");
    NSUInteger length = 0;
    unsigned char *decoded = charon_base64_decode(base64Data.bytes, base64Data.length, options, &length);
    if (!decoded)
        return nil;
    if (!length) {
        free(decoded);
        return [self initWithBytes:NULL length:0];
    }
    return [self initWithBytesNoCopy:decoded length:length freeWhenDone:YES];
}

- (NSData *)base64EncodedDataWithOptions:(NSDataBase64EncodingOptions)options
{
    NSUInteger length = 0;
    char *encoded = charon_base64_encode(self, options, _cmd, &length);
    if (!length) {
        free(encoded);
        return [NSData data];
    }
    return [NSData dataWithBytesNoCopy:encoded length:length freeWhenDone:YES];
}

@end
