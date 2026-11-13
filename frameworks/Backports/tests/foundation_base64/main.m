#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static NSString *escape(NSString *value)
{
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger index = 0; index < value.length; index++) {
        unichar character = [value characterAtIndex:index];
        if (character == '\r')
            [result appendString:@"\\r"];
        else if (character == '\n')
            [result appendString:@"\\n"];
        else if (character < 0x20 || character > 0x7E)
            [result appendFormat:@"\\u%04x", character];
        else
            [result appendFormat:@"%C", character];
    }
    return result;
}

static NSString *hex(NSData *data)
{
    if (!data)
        return @"nil";
    NSMutableString *result = [NSMutableString stringWithFormat:@"%lu:", (unsigned long)data.length];
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++)
        [result appendFormat:@"%02x", bytes[index]];
    return result;
}

static NSData *sample(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    unsigned char *bytes = data.mutableBytes;
    uint32_t state = (uint32_t)length * 2654435761u + 12345u;
    for (NSUInteger index = 0; index < length; index++) {
        state = state * 1664525u + 1013904223u;
        bytes[index] = (unsigned char)(state >> 24);
    }
    return data;
}

static void line(NSString *label, NSString *value)
{
    printf("%s => %s\n", label.UTF8String, escape(value).UTF8String);
}

static NSString *guarded(NSString *(^block)(void))
{
    @try {
        return block();
    } @catch (NSException *exception) {
        return [@"raises " stringByAppendingString:exception.name];
    }
}

static NSArray<NSString *> *decode_inputs(void)
{
    return @[
        @"", @"Zg==", @"Zg", @"Zg=", @"Zm8=", @"Zm8", @"Zm9v", @"Zm9vYg==", @"Zm9vYmE=", @"Zm9vYmFy", @"Zm9vYmF", @"Zm9vY", @"Z",
        @"=", @"==", @"===", @"====", @"Z===", @"Zg===", @"Zg====", @"Zg==Zg==", @"Zg==Zm8=", @"Zg=g", @"Zg==g", @"Z=g=", @"Zm8=Zm8=", @"Zm8=\n",
        @"Zm9v\nYmFy", @"Zm9v\r\nYmFy", @"Zm9v YmFy", @" Zm9vYmFy", @"Zm9vYmFy ", @"Zm9v\tYmFy", @"Zm9vY mFy", @"Zm9vYmFy\n", @"\nZm9vYmFy",
        @"Zm9v-YmFy", @"Zm9v_YmFy", @"Zm9v*YmFy", @"Zm9v!", @"!Zm9v", @"Zm!9v", @"Zm9vYg==!", @"Zm9vYg=!=", @"Zm9vYg =  =", @"Zm9vYg=\n=", @"Zm9vYg==\n",
        @"Zm9vYg==\nZm9v", @"Zg==\n\n", @"Z m 9 v", @"éZm9v", @"Zm9vé", @"Zmé9v", @"Zm9v€YmFy", @"Zm9v\U0001F600", @"//8=", @"+/+/", @"AAAA", @"AAA=", @"AA==",
        @"A", @"AB", @"ABC", @"ABCD", @"ABCDE", @"ABCDEF", @"ABCDEFG", @"ABCDEFGH", @"AB==", @"AB=", @"A===", @"A=BC", @"=ABC", @"A=", @"=A", @"Zg==Zg", @"Zg=\n=Zg==",
        @"VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZy4=",
        @"VGhlIHF1aWNr\nIGJyb3duIGZveCBq\ndW1wcyBvdmVyIHRo\nZSBsYXp5IGRvZy4=",
    ];
}

static BOOL implemented_outside_the_system(SEL selector)
{
    Dl_info found;
    if (!class_respondsToSelector([NSData class], selector))
        return NO;
    IMP implementation = class_getMethodImplementation([NSData class], selector);
    return dladdr((void *)implementation, &found) && strncmp(found.dli_fname, "/System/", 8) != 0 && strstr(found.dli_fname, "libobjc") == NULL;
}

#ifdef REVENANT_RELEASE_PROBE
static void release_probe(void)
{
    SEL asked[] = {@selector(base64Encoding), @selector(initWithBase64Encoding:), @selector(base64EncodedStringWithOptions:),
                   @selector(base64EncodedDataWithOptions:), @selector(initWithBase64EncodedString:options:), @selector(initWithBase64EncodedData:options:)};
    for (unsigned index = 0; index < sizeof asked / sizeof *asked; index++)
        printf("RESPONDS %s %s\n", sel_getName(asked[index]), [NSData instancesRespondToSelector:asked[index]] ? "yes" : "no");
    NSUInteger lengths[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 100, 255, 256, 1000, 4097};
    for (unsigned index = 0; index < sizeof lengths / sizeof *lengths; index++) {
        NSUInteger length = lengths[index];
        NSString *label = [NSString stringWithFormat:@"encode length %lu options 0 string", (unsigned long)length];
        line(label, guarded(^{
            return [sample(length) base64Encoding];
        }));
    }
    for (NSString *input in decode_inputs()) {
        for (unsigned options = 0; options < 2; options++) {
            NSString *label = [NSString stringWithFormat:@"decode '%@' options %u string", escape(input), options];
            line(label, guarded(^{
                return hex([[NSData alloc] initWithBase64Encoding:input]);
            }));
        }
    }
    NSString *absent = nil;
    for (unsigned options = 0; options < 2; options++) {
        NSString *label = [NSString stringWithFormat:@"nil options %u string", options];
        line(label, guarded(^{
            return hex([[NSData alloc] initWithBase64Encoding:absent]);
        }));
    }
    printf("done\n");
}
#endif

int main(void)
{
    @autoreleasepool {
#ifdef REVENANT_RELEASE_PROBE
        release_probe();
        return 0;
#endif
        SEL selectors[] = {@selector(base64EncodedStringWithOptions:), @selector(base64EncodedDataWithOptions:),
                           @selector(initWithBase64EncodedString:options:), @selector(initWithBase64EncodedData:options:)};
        unsigned outside = 0;
        for (unsigned index = 0; index < 4; index++)
            outside += implemented_outside_the_system(selectors[index]);
        printf("OUTSIDE_THE_SYSTEM %u\n", outside);

        NSDataBase64EncodingOptions lines[] = {0, NSDataBase64Encoding64CharacterLineLength, NSDataBase64Encoding76CharacterLineLength,
                                               NSDataBase64Encoding64CharacterLineLength | NSDataBase64Encoding76CharacterLineLength};
        NSDataBase64EncodingOptions endings[] = {0, NSDataBase64EncodingEndLineWithCarriageReturn, NSDataBase64EncodingEndLineWithLineFeed,
                                                 NSDataBase64EncodingEndLineWithCarriageReturn | NSDataBase64EncodingEndLineWithLineFeed};
        NSUInteger lengths[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 100, 255, 256, 1000, 4097};
        for (unsigned length_index = 0; length_index < sizeof lengths / sizeof *lengths; length_index++) {
            NSData *data = sample(lengths[length_index]);
            for (unsigned line_index = 0; line_index < 4; line_index++) {
                for (unsigned ending_index = 0; ending_index < 4; ending_index++) {
                    NSDataBase64EncodingOptions options = lines[line_index] | endings[ending_index];
                    NSString *label = [NSString stringWithFormat:@"encode length %lu options %lu", (unsigned long)lengths[length_index], (unsigned long)options];
                    NSString *string = [data base64EncodedStringWithOptions:options];
                    line([label stringByAppendingString:@" string"], string);
                    NSData *encoded = [data base64EncodedDataWithOptions:options];
                    line([label stringByAppendingString:@" data"], [[NSString alloc] initWithData:encoded encoding:NSASCIIStringEncoding]);
                    line([label stringByAppendingString:@" round trip"], hex([[NSData alloc] initWithBase64EncodedString:string options:NSDataBase64DecodingIgnoreUnknownCharacters]));
                    line([label stringByAppendingString:@" same bytes"], [hex([[NSData alloc] initWithBase64EncodedData:encoded options:NSDataBase64DecodingIgnoreUnknownCharacters]) isEqualToString:hex(data)] ? @"yes" : @"no");
                }
            }
        }

        NSArray<NSString *> *inputs = decode_inputs();
        NSDataBase64DecodingOptions decodings[] = {0, NSDataBase64DecodingIgnoreUnknownCharacters};
        for (NSString *input in inputs) {
            for (unsigned index = 0; index < 2; index++) {
                NSDataBase64DecodingOptions option = decodings[index];
                NSString *label = [NSString stringWithFormat:@"decode '%@' options %lu", escape(input), (unsigned long)decodings[index]];
                line([label stringByAppendingString:@" string"], guarded(^{
                    return hex([[NSData alloc] initWithBase64EncodedString:input options:option]);
                }));
                NSData *ascii = [input dataUsingEncoding:NSUTF8StringEncoding];
                line([label stringByAppendingString:@" data"], guarded(^{
                    return hex([[NSData alloc] initWithBase64EncodedData:ascii options:option]);
                }));
            }
        }

        NSString *absent = nil;
        NSData *missing = nil;
        for (unsigned index = 0; index < 2; index++) {
            NSDataBase64DecodingOptions option = decodings[index];
            NSString *label = [NSString stringWithFormat:@"nil options %lu", (unsigned long)decodings[index]];
            line([label stringByAppendingString:@" string"], guarded(^{
                return hex([[NSData alloc] initWithBase64EncodedString:absent options:option]);
            }));
            line([label stringByAppendingString:@" data"], guarded(^{
                return hex([[NSData alloc] initWithBase64EncodedData:missing options:option]);
            }));
        }

        NSData *bytes = [NSData dataWithBytes:"\x00\xff\x10" length:3];
        line(@"mutable data", [[NSMutableData dataWithData:bytes] base64EncodedStringWithOptions:0]);
        line(@"mutable init", hex([[NSMutableData alloc] initWithBase64EncodedString:@"AP8Q" options:0]));
        line(@"subdata", [[bytes subdataWithRange:NSMakeRange(1, 2)] base64EncodedStringWithOptions:0]);
        line(@"unknown option bits", [bytes base64EncodedStringWithOptions:0x100]);
        line(@"decoding unknown bits", hex([[NSData alloc] initWithBase64EncodedString:@"AP8Q" options:0x100]));
        printf("done\n");
    }
    return 0;
}
