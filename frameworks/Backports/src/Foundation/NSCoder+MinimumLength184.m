#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static void revenant_short_bytes(NSCoder *coder, NSString *key, NSUInteger found, NSUInteger minimum)
{
    NSString *description = key ? [NSString stringWithFormat:@"decoded %lu bytes for key '%@', fewer than the required %lu", (unsigned long)found, key, (unsigned long)minimum]
                                : [NSString stringWithFormat:@"decoded %lu bytes, fewer than the required %lu", (unsigned long)found, (unsigned long)minimum];
    [coder failWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSCoderReadCorruptError userInfo:@{NSDebugDescriptionErrorKey: description}]];
}

@implementation NSCoder (RevenantMinimumLength184)

- (const uint8_t *)decodeBytesForKey:(NSString *)key minimumLength:(NSUInteger)length
{
    NSUInteger found = 0;
    const uint8_t *bytes = [self decodeBytesForKey:key returnedLength:&found];
    if (bytes && found < length) {
        revenant_short_bytes(self, key, found, length);
        return NULL;
    }
    return bytes;
}

- (void *)decodeBytesWithMinimumLength:(NSUInteger)length
{
    NSUInteger found = 0;
    void *bytes = [self decodeBytesWithReturnedLength:&found];
    if (bytes && found < length) {
        revenant_short_bytes(self, nil, found, length);
        return NULL;
    }
    return bytes;
}

@end
