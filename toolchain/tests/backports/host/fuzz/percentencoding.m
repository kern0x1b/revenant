#import <Foundation/Foundation.h>
#import <objc/message.h>

#import "fuzz.h"

void host_attach_prefixed(const char *prefix);

static uint32_t roll(uint32_t n) { return fuzz_roll(n); }

static unichar piece(void)
{
    static const unichar interesting[] = {'%', ' ', '/', '?', '#', '[', ']', '@', ':', '&', '=', '+', ';', ',', '$', '!', '\'', '(', ')', '*',
                                          '~', '-', '.', '_', '"', '<', '>', '\\', '^', '`', '{', '|', '}', 0x7f, 0, '\n', 0xe9, 0x436, 0x4e2d,
                                          0xfeff, 0xfffd, 0xd83d, 0xde00, 0xdc00, 0xd800, 'A', 'z', '0', '9', 'f', 'F', 'g'};
    uint32_t r = roll(4);
    if (r == 0)
        return (unichar)(0x20 + roll(0x5f));
    if (r == 1)
        return (unichar)roll(0x10000);
    return interesting[roll(sizeof interesting / sizeof interesting[0])];
}

static NSString *text(void)
{
    uint32_t length = roll(12);
    unichar buffer[64];
    NSUInteger used = 0;
    for (uint32_t i = 0; i < length; i++) {
        if (roll(12) == 0 && used + 12 <= 60) {
            static const char *sequences[] = {"%C0%AF", "%C1%BF", "%E0%80%80", "%E0%9F%BF", "%E0%A0%80", "%ED%A0%80", "%ED%9F%BF", "%EF%BF%BD",
                                              "%F0%8F%BF%BF", "%F0%90%80%80", "%F4%8F%BF%BF", "%F4%90%80%80", "%F5%80%80%80", "%E2%82", "%80"};
            for (const char *sequence = sequences[roll(sizeof sequences / sizeof *sequences)]; *sequence; sequence++)
                buffer[used++] = (unichar)*sequence;
        } else if (roll(5) == 0 && used + 3 <= 60) {
            static const char *hex = "0123456789abcdefABCDEFgG";
            buffer[used++] = '%';
            buffer[used++] = hex[roll(24)];
            buffer[used++] = hex[roll(24)];
        } else if (roll(15) == 0 && used + 2 <= 60) {
            uint32_t astral = 0x10000 + roll(0xfffff);
            buffer[used++] = (unichar)(0xd800 + ((astral - 0x10000) >> 10));
            buffer[used++] = (unichar)(0xdc00 + ((astral - 0x10000) & 0x3ff));
        } else {
            buffer[used++] = piece();
        }
    }
    return [NSString stringWithCharacters:buffer length:used];
}

static NSString *shown(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[NSData class]])
        return [NSString stringWithFormat:@"data %@", [value description]];
    NSMutableString *made = [NSMutableString string];
    NSString *string = value;
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if (c >= 0x20 && c < 0x7f)
            [made appendFormat:@"%C", c];
        else
            [made appendFormat:@"\\u%04x", c];
    }
    return made;
}

static NSString *call(id receiver, NSString *selector, id argument, BOOL ours)
{
    SEL chosen = NSSelectorFromString(ours ? [@"charonHost_" stringByAppendingString:selector] : selector);
    @try {
        return shown(argument ? ((id (*)(id, SEL, id))objc_msgSend)(receiver, chosen, argument) : ((id (*)(id, SEL))objc_msgSend)(receiver, chosen));
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raised %@", exception.name];
    }
}


static void character_sets(void)
{
    for (NSString *name in @[@"URLUserAllowedCharacterSet", @"URLPasswordAllowedCharacterSet", @"URLHostAllowedCharacterSet",
                             @"URLPathAllowedCharacterSet", @"URLQueryAllowedCharacterSet", @"URLFragmentAllowedCharacterSet"]) {
        NSCharacterSet *system = ((id (*)(id, SEL))objc_msgSend)([NSCharacterSet class], NSSelectorFromString(name));
        NSCharacterSet *port = ((id (*)(id, SEL))objc_msgSend)([NSCharacterSet class], NSSelectorFromString([@"charonHost_" stringByAppendingString:name]));
        NSMutableArray *wrong = [NSMutableArray array];
        for (UTF32Char c = 0; c < 0x110000; c++)
            if ([system longCharacterIsMember:c] != [port longCharacterIsMember:c] && wrong.count < 8)
                [wrong addObject:[NSString stringWithFormat:@"U+%04X system %d", c, [system longCharacterIsMember:c]]];
        fuzz_compare([@"set." stringByAppendingString:name], @"membership", @"same", wrong.count ? [wrong componentsJoinedByString:@", "] : @"same");
    }
}

static NSString *allowed_name;
static NSCharacterSet *allowed_ours;

static NSCharacterSet *predefined(NSString *name, BOOL ours)
{
    SEL selector = NSSelectorFromString(ours ? [@"charonHost_" stringByAppendingString:name] : name);
    NSCharacterSet *set = ((id (*)(id, SEL))objc_msgSend)([NSCharacterSet class], selector);
    if (!ours)
        allowed_ours = predefined(name, YES);
    return set;
}

static NSCharacterSet *allowed_set(void)
{
    uint32_t pick = roll(8);
    allowed_ours = nil;
    allowed_name = @[@"query", @"path", @"host", @"alphanumeric", @"custom", @"inverted fragment", @"percent e-acute zhe space a", @"all of the BMP"][pick];
    switch (pick) {
        case 0: return predefined(@"URLQueryAllowedCharacterSet", NO);
        case 1: return predefined(@"URLPathAllowedCharacterSet", NO);
        case 2: return predefined(@"URLHostAllowedCharacterSet", NO);
        case 3: return [NSCharacterSet alphanumericCharacterSet];
        case 4: {
            NSString *members = text();
            allowed_name = [@"custom " stringByAppendingString:shown(members)];
            return [NSCharacterSet characterSetWithCharactersInString:members];
        }
        case 5: return [[NSCharacterSet URLFragmentAllowedCharacterSet] invertedSet];
        case 6: return [NSCharacterSet characterSetWithCharactersInString:@"%éж a"];
        default: return [NSCharacterSet characterSetWithRange:NSMakeRange(0, 0x10000)];
    }
}

static NSData *bytes(void)
{
    NSMutableData *data = [NSMutableData dataWithLength:roll(3) == 0 ? roll(200) : roll(12)];
    for (NSUInteger i = 0; i < data.length; i++)
        ((uint8_t *)data.mutableBytes)[i] = (uint8_t)fuzz_roll(256);
    return data;
}

static NSString *base64_text(void)
{
    static const char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    NSMutableString *made = [NSMutableString string];
    uint32_t length = roll(30);
    for (uint32_t i = 0; i < length; i++) {
        uint32_t r = roll(20);
        if (r == 0) [made appendString:@"="];
        else if (r == 1) [made appendString:@"\r\n"];
        else if (r == 2) [made appendString:@" "];
        else if (r == 3) [made appendFormat:@"%C", piece()];
        else if (r == 4) [made appendString:@"-_"];
        else if (r == 5) {
            uint32_t kept = 1 + roll(3);
            for (uint32_t k = 0; k < kept; k++)
                [made appendFormat:@"%c", alphabet[roll(64)]];
            [made appendString:[@"===" substringToIndex:4 - kept]];
        }
        else [made appendFormat:@"%c", alphabet[roll(64)]];
    }
    if (roll(3) == 0) {
        NSData *data = bytes();
        return [data base64EncodedStringWithOptions:roll(2) ? NSDataBase64Encoding64CharacterLineLength : 0];
    }
    return made;
}

static NSString *padding_inside(NSString *encoded)
{
    NSCharacterSet *alphabet = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"];
    NSRange padding = [encoded rangeOfString:@"="];
    if (padding.location == NSNotFound)
        return @"";
    NSRange after = [encoded rangeOfCharacterFromSet:alphabet options:0 range:NSMakeRange(padding.location, encoded.length - padding.location)];
    return after.location == NSNotFound ? @"" : @".paddingInside";
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        host_attach_prefixed("");
        int rounds = 20000;
        fuzz_start(argc, argv, &rounds);
        character_sets();
        for (int round = 0; round < rounds; round++) @autoreleasepool {
            NSString *subject = text();
            NSCharacterSet *allowed = allowed_set();
            fuzz_compare([@"adding." stringByAppendingString:[allowed_name hasPrefix:@"custom"] ? @"custom" : [allowed_name stringByReplacingOccurrencesOfString:@" " withString:@"_"]],
                         [NSString stringWithFormat:@"[%@] with the %@ set", shown(subject), allowed_name],
                    call(subject, @"stringByAddingPercentEncodingWithAllowedCharacters:", allowed, NO),
                    call(subject, @"stringByAddingPercentEncodingWithAllowedCharacters:", allowed_ours ? allowed_ours : allowed, YES));
            fuzz_compare(@"removing", [NSString stringWithFormat:@"[%@]", shown(subject)],
                    call(subject, @"stringByRemovingPercentEncoding", nil, NO), call(subject, @"stringByRemovingPercentEncoding", nil, YES));
            NSData *data = bytes();
            NSUInteger encoding = [@[@0, @(NSDataBase64Encoding64CharacterLineLength), @(NSDataBase64Encoding76CharacterLineLength),
                                    @(NSDataBase64Encoding64CharacterLineLength | NSDataBase64EncodingEndLineWithCarriageReturn),
                                    @(NSDataBase64Encoding76CharacterLineLength | NSDataBase64EncodingEndLineWithLineFeed),
                                    @(NSDataBase64EncodingEndLineWithCarriageReturn | NSDataBase64EncodingEndLineWithLineFeed)][roll(6)] unsignedIntegerValue];
            NSString *systemEncoded = shown([data base64EncodedStringWithOptions:encoding]);
            NSString *portEncoded = shown(((id (*)(id, SEL, NSUInteger))objc_msgSend)(data, NSSelectorFromString(@"charonHost_base64EncodedStringWithOptions:"), encoding));
            fuzz_compare(@"encode.string", [NSString stringWithFormat:@"%lu bytes options %lu", (unsigned long)data.length, (unsigned long)encoding], systemEncoded, portEncoded);
            NSString *systemData = shown([data base64EncodedDataWithOptions:encoding]);
            NSString *portData = shown(((id (*)(id, SEL, NSUInteger))objc_msgSend)(data, NSSelectorFromString(@"charonHost_base64EncodedDataWithOptions:"), encoding));
            fuzz_compare(@"encode.data", [NSString stringWithFormat:@"%lu bytes options %lu", (unsigned long)data.length, (unsigned long)encoding], systemData, portData);
            NSString *encoded = base64_text();
            NSUInteger decoding = roll(2) ? NSDataBase64DecodingIgnoreUnknownCharacters : 0;
            NSString *systemDecoded = shown([[NSData alloc] initWithBase64EncodedString:encoded options:decoding]);
            NSString *portDecoded = shown(((id (*)(id, SEL, id, NSUInteger))objc_msgSend)([NSData alloc], NSSelectorFromString(@"initCharonHostWithBase64EncodedString:options:"), encoded, decoding));
            fuzz_compare([NSString stringWithFormat:@"decode.string.options%lu%@", (unsigned long)decoding, padding_inside(encoded)], [NSString stringWithFormat:@"[%@]", shown(encoded)], systemDecoded, portDecoded);
            NSData *encodedData = [encoded dataUsingEncoding:NSUTF8StringEncoding];
            if (!encodedData)
                continue;
            NSString *systemFromData = shown([[NSData alloc] initWithBase64EncodedData:encodedData options:decoding]);
            NSString *portFromData = shown(((id (*)(id, SEL, id, NSUInteger))objc_msgSend)([NSData alloc], NSSelectorFromString(@"initCharonHostWithBase64EncodedData:options:"), encodedData, decoding));
            fuzz_compare([NSString stringWithFormat:@"decode.data.options%lu%@", (unsigned long)decoding, padding_inside(encoded)], [NSString stringWithFormat:@"[%@]", shown(encoded)], systemFromData, portFromData);
        }
        return fuzz_finish();
    }
}
