#import <Foundation/Foundation.h>

static const char charon_hex_digits[] = "0123456789ABCDEF";

static int charon_hex_value(unichar character)
{
    if (character >= '0' && character <= '9')
        return character - '0';
    if (character >= 'A' && character <= 'F')
        return character - 'A' + 10;
    if (character >= 'a' && character <= 'f')
        return character - 'a' + 10;
    return -1;
}

static NSUInteger charon_decode_utf8(const uint8_t *bytes, NSUInteger length, unichar *output)
{
    NSUInteger used = 0;
    NSUInteger index = 0;
    while (index < length) {
        uint8_t lead = bytes[index];
        UTF32Char scalar;
        NSUInteger extra;
        UTF32Char minimum;
        if (lead < 0x80) {
            scalar = lead;
            extra = 0;
            minimum = 0;
        } else if (lead >= 0xC2 && lead <= 0xDF) {
            scalar = lead & 0x1F;
            extra = 1;
            minimum = 0x80;
        } else if (lead >= 0xE0 && lead <= 0xEF) {
            scalar = lead & 0x0F;
            extra = 2;
            minimum = 0x800;
        } else if (lead >= 0xF0 && lead <= 0xF4) {
            scalar = lead & 0x07;
            extra = 3;
            minimum = 0x10000;
        } else {
            return NSNotFound;
        }
        if (length - index <= extra)
            return NSNotFound;
        for (NSUInteger offset = 1; offset <= extra; offset++) {
            uint8_t next = bytes[index + offset];
            if ((next & 0xC0) != 0x80)
                return NSNotFound;
            scalar = (scalar << 6) | (next & 0x3F);
        }
        if (scalar < minimum || scalar > 0x10FFFF || (scalar >= 0xD800 && scalar <= 0xDFFF))
            return NSNotFound;
        if (scalar >= 0x10000) {
            scalar -= 0x10000;
            output[used++] = (unichar)(0xD800 + (scalar >> 10));
            output[used++] = (unichar)(0xDC00 + (scalar & 0x3FF));
        } else {
            output[used++] = (unichar)scalar;
        }
        index += extra + 1;
    }
    return used;
}

@implementation NSString (CharonURLUtilities)

- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowedCharacters
{
    BOOL allowed[128];
    for (unichar character = 0; character < 128; character++)
        allowed[character] = [allowedCharacters characterIsMember:character];
    BOOL path = allowedCharacters == [NSCharacterSet URLPathAllowedCharacterSet];
    if (allowedCharacters == [NSCharacterSet URLHostAllowedCharacterSet] && !([self hasPrefix:@"["] && [self hasSuffix:@"]"] && self.length > 1))
        allowed[':'] = allowed['['] = allowed[']'] = NO;
    BOOL colon = allowed[':'];
    if (path)
        allowed[':'] = NO;
    NSUInteger length = self.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    unichar *output = malloc((length ? length : 1) * 9 * sizeof(unichar));
    [self getCharacters:characters range:NSMakeRange(0, length)];
    NSUInteger used = 0;
    NSString *result = nil;
    NSUInteger index = 0;
    for (; index < length; index++) {
        unichar character = characters[index];
        if (path && character == '/')
            allowed[':'] = colon;
        if (character < 128 && allowed[character]) {
            output[used++] = character;
            continue;
        }
        UTF32Char scalar = character;
        if (character >= 0xD800 && character <= 0xDBFF) {
            if (index + 1 >= length || characters[index + 1] < 0xDC00 || characters[index + 1] > 0xDFFF)
                break;
            scalar = 0x10000 + ((character - 0xD800) << 10) + (characters[index + 1] - 0xDC00);
            index++;
        } else if (character >= 0xDC00 && character <= 0xDFFF) {
            break;
        }
        uint8_t bytes[4];
        NSUInteger count;
        if (scalar < 0x80) {
            bytes[0] = (uint8_t)scalar;
            count = 1;
        } else if (scalar < 0x800) {
            bytes[0] = (uint8_t)(0xC0 | (scalar >> 6));
            bytes[1] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 2;
        } else if (scalar < 0x10000) {
            bytes[0] = (uint8_t)(0xE0 | (scalar >> 12));
            bytes[1] = (uint8_t)(0x80 | ((scalar >> 6) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 3;
        } else {
            bytes[0] = (uint8_t)(0xF0 | (scalar >> 18));
            bytes[1] = (uint8_t)(0x80 | ((scalar >> 12) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | ((scalar >> 6) & 0x3F));
            bytes[3] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 4;
        }
        for (NSUInteger byte = 0; byte < count; byte++) {
            output[used++] = '%';
            output[used++] = (unichar)charon_hex_digits[bytes[byte] >> 4];
            output[used++] = (unichar)charon_hex_digits[bytes[byte] & 0x0F];
        }
    }
    if (index >= length)
        result = [NSString stringWithCharacters:output length:used];
    free(characters);
    free(output);
    return result;
}

- (NSString *)stringByRemovingPercentEncoding
{
    NSUInteger length = self.length;
    unichar *characters = malloc((length ? length : 1) * sizeof(unichar));
    unichar *output = malloc((length ? length : 1) * sizeof(unichar));
    uint8_t *bytes = malloc(length ? length : 1);
    [self getCharacters:characters range:NSMakeRange(0, length)];
    NSUInteger used = 0;
    NSUInteger index = 0;
    BOOL valid = YES;
    for (NSUInteger scan = 0; scan < length && valid; scan++) {
        if (characters[scan] >= 0xD800 && characters[scan] <= 0xDBFF) {
            if (scan + 1 < length && characters[scan + 1] >= 0xDC00 && characters[scan + 1] <= 0xDFFF)
                scan++;
            else
                valid = NO;
        } else if (characters[scan] >= 0xDC00 && characters[scan] <= 0xDFFF) {
            valid = NO;
        }
    }
    while (valid && index < length) {
        if (characters[index] != '%') {
            output[used++] = characters[index++];
            continue;
        }
        NSUInteger count = 0;
        while (index < length && characters[index] == '%') {
            int high = index + 2 < length ? charon_hex_value(characters[index + 1]) : -1;
            int low = index + 2 < length ? charon_hex_value(characters[index + 2]) : -1;
            if (high < 0 || low < 0) {
                valid = NO;
                break;
            }
            bytes[count++] = (uint8_t)(high << 4 | low);
            index += 3;
        }
        if (!valid)
            break;
        NSUInteger decoded = charon_decode_utf8(bytes, count, output + used);
        if (decoded == NSNotFound)
            valid = NO;
        else
            used += decoded;
    }
    NSString *result = valid ? [NSString stringWithCharacters:output length:used] : nil;
    free(characters);
    free(output);
    free(bytes);
    return result;
}

@end
