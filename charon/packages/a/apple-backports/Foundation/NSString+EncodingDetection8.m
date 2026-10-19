#import <Foundation/Foundation.h>

NSString * const NSStringEncodingDetectionSuggestedEncodingsKey = @"NSStringEncodingDetectionSuggestedEncodingsKey";
NSString * const NSStringEncodingDetectionDisallowedEncodingsKey = @"NSStringEncodingDetectionDisallowedEncodingsKey";
NSString * const NSStringEncodingDetectionUseOnlySuggestedEncodingsKey = @"NSStringEncodingDetectionUseOnlySuggestedEncodingsKey";
NSString * const NSStringEncodingDetectionAllowLossyKey = @"NSStringEncodingDetectionAllowLossyKey";
NSString * const NSStringEncodingDetectionFromWindowsKey = @"NSStringEncodingDetectionFromWindowsKey";
NSString * const NSStringEncodingDetectionLossySubstitutionKey = @"NSStringEncodingDetectionLossySubstitutionKey";
NSString * const NSStringEncodingDetectionLikelyLanguageKey = @"NSStringEncodingDetectionLikelyLanguageKey";

static BOOL charon_bom(NSData *data, const uint8_t *mark, NSUInteger length)
{
    if (data.length < length)
        return NO;
    return memcmp(data.bytes, mark, length) == 0;
}

static NSStringEncoding charon_encoding_from_bom(NSData *data)
{
    static const uint8_t utf32be[] = {0x00, 0x00, 0xFE, 0xFF};
    static const uint8_t utf32le[] = {0xFF, 0xFE, 0x00, 0x00};
    static const uint8_t utf8bom[] = {0xEF, 0xBB, 0xBF};
    static const uint8_t utf16be[] = {0xFE, 0xFF};
    static const uint8_t utf16le[] = {0xFF, 0xFE};
    /* the generic, non-endian-qualified constants ask NSString to read and consume the
       byte-order mark itself; the endian-qualified ones treat a leading FE FF/FF FE as an
       ordinary character, which is what a caller who already knows the endianness wants,
       but not what a byte-order mark found by sniffing means */
    if (charon_bom(data, utf32be, sizeof utf32be) || charon_bom(data, utf32le, sizeof utf32le))
        return NSUTF32StringEncoding;
    if (charon_bom(data, utf8bom, sizeof utf8bom))
        return NSUTF8StringEncoding;
    if (charon_bom(data, utf16be, sizeof utf16be) || charon_bom(data, utf16le, sizeof utf16le))
        return NSUnicodeStringEncoding;
    return 0;
}

static BOOL charon_all_ascii(NSData *data)
{
    const uint8_t *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++) {
        if (bytes[index] >= 0x80)
            return NO;
    }
    return YES;
}

@implementation NSString (CharonEncodingDetection8)

+ (NSStringEncoding)stringEncodingForData:(NSData *)data
                          encodingOptions:(NSDictionary *)opts
                          convertedString:(NSString **)string
                      usedLossyConversion:(BOOL *)usedLossyConversion
{
    if (usedLossyConversion)
        *usedLossyConversion = NO;
    if (string)
        *string = nil;
    if (!data)
        return 0;
    if (data.length == 0) {
        if (string)
            *string = @"";
        return NSUTF8StringEncoding;
    }
    NSArray *suggested = opts[NSStringEncodingDetectionSuggestedEncodingsKey];
    NSArray *disallowed = opts[NSStringEncodingDetectionDisallowedEncodingsKey];
    BOOL onlySuggested = [opts[NSStringEncodingDetectionUseOnlySuggestedEncodingsKey] boolValue];
    BOOL allowLossy = opts[NSStringEncodingDetectionAllowLossyKey] ? [opts[NSStringEncodingDetectionAllowLossyKey] boolValue] : YES;
    NSString *substitution = opts[NSStringEncodingDetectionLossySubstitutionKey] ?: @"�";
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSNumber *encoding in suggested)
        [candidates addObject:encoding];
    if (!onlySuggested) {
        NSStringEncoding bom = charon_encoding_from_bom(data);
        if (bom)
            [candidates addObject:@(bom)];
        if (charon_all_ascii(data))
            [candidates addObject:@(NSASCIIStringEncoding)];
        [candidates addObject:@(NSUTF8StringEncoding)];
        [candidates addObject:@(NSWindowsCP1252StringEncoding)];
        [candidates addObject:@(NSISOLatin1StringEncoding)];
        [candidates addObject:@(NSMacOSRomanStringEncoding)];
    }
    for (NSNumber *disallow in disallowed)
        [candidates removeObject:disallow];
    for (NSNumber *candidate in candidates) {
        NSStringEncoding encoding = candidate.unsignedIntegerValue;
        NSString *decoded = [[NSString alloc] initWithData:data encoding:encoding];
        if (decoded) {
            if (string)
                *string = decoded;
            return encoding;
        }
    }
    if (!allowLossy || candidates.count == 0)
        return 0;
    NSStringEncoding fallback = [candidates.firstObject unsignedIntegerValue];
    NSMutableString *lossy = [NSMutableString string];
    const uint8_t *bytes = data.bytes;
    NSUInteger index = 0;
    while (index < data.length) {
        NSUInteger chunk = 1;
        NSString *piece = nil;
        while (index + chunk <= data.length) {
            piece = [[NSString alloc] initWithBytes:bytes + index length:chunk encoding:fallback];
            if (piece)
                break;
            chunk++;
        }
        if (piece) {
            [lossy appendString:piece];
            index += chunk;
        } else {
            [lossy appendString:substitution];
            index++;
        }
    }
    if (usedLossyConversion)
        *usedLossyConversion = YES;
    if (string)
        *string = lossy;
    return fallback;
}

@end
