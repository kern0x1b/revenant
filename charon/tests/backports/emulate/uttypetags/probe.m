#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

static NSString *encodeBytes(const unsigned char *bytes, NSUInteger count)
{
    static const char alphabet[] = "abcdefghkmnpqrstuvwxyz0123456789";
    NSMutableString *out = [NSMutableString stringWithString:@"dyn.a"];
    unsigned int accumulator = 0;
    int bits = 0;
    for (NSUInteger index = 0; index < count; index++) {
        accumulator = (accumulator << 8) | bytes[index];
        bits += 8;
        while (bits >= 5) {
            bits -= 5;
            [out appendFormat:@"%c", alphabet[(accumulator >> bits) & 31]];
        }
        accumulator &= (1u << bits) - 1;
    }
    if (bits > 0)
        [out appendFormat:@"%c", alphabet[(accumulator << (5 - bits)) & 31]];
    return out;
}

static NSString *describe(CFArrayRef array)
{
    if (!array)
        return @"NULL";
    NSMutableString *out = [NSMutableString stringWithString:@"["];
    for (id item in (__bridge NSArray *)array) {
        NSMutableString *text = [NSMutableString string];
        NSString *value = item;
        for (NSUInteger index = 0; index < value.length; index++)
            [text appendFormat:@"%04X", [value characterAtIndex:index]];
        [out appendFormat:@"<%@>", text];
    }
    [out appendString:@"]"];
    return out;
}

static void answer(NSString *uti)
{
    NSArray *classes = @[@"public.filename-extension", @"public.mime-type", @"com.apple.ostype", @"public.pathname", @"com.apple.nspboard-type"];
    for (NSString *tagClass in classes) {
        CFArrayRef tags = UTTypeCopyAllTagsWithClass((__bridge CFStringRef)uti, (__bridge CFStringRef)tagClass);
        printf("TAGS %s|%s|%s\n", [uti UTF8String], [tagClass UTF8String], [describe(tags) UTF8String]);
        if (tags)
            CFRelease(tags);
    }
}

int main(void)
{
    @autoreleasepool {
        NSArray *declared = @[
#include "declared-list.inc"
        ];
        for (NSString *uti in declared)
            answer(uti);

        unsigned int state = 20261017;
        const unsigned char pool[] = "1234b=:,\\ax\xC3\xA9\xE9-0000AFfCcdg";
        NSUInteger poolCount = sizeof(pool) - 1;
        for (int round = 0; round < 2000; round++) {
            unsigned char bytes[16];
            NSUInteger length = 1 + (NSUInteger)(((state = state * 1103515245u + 12345u) >> 16) % 16);
            for (NSUInteger index = 0; index < length; index++) {
                state = state * 1103515245u + 12345u;
                bytes[index] = pool[((state >> 16) & 0x7FFF) % poolCount];
            }
            answer(encodeBytes(bytes, length));
        }
        printf("TAGS done\n");
    }
    return 0;
}
