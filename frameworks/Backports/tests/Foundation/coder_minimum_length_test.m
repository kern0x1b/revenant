#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const uint8_t *revenant_keyed(NSCoder *coder, NSString *key, NSUInteger length)
{
    SEL selector = @selector(decodeBytesForKey:minimumLength:);
    return REVENANT_IMP(NSCoder, selector, const uint8_t *(*)(id, SEL, NSString *, NSUInteger))(coder, selector, key, length);
}

static void *revenant_unkeyed(NSCoder *coder, NSUInteger length)
{
    SEL selector = @selector(decodeBytesWithMinimumLength:);
    return REVENANT_IMP(NSCoder, selector, void *(*)(id, SEL, NSUInteger))(coder, selector, length);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    uint8_t payload[4] = {1, 2, 3, 4};
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeBytes:payload length:sizeof payload forKey:@"bytes"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = NO;
    unarchiver.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
    const uint8_t *enough = revenant_keyed(unarchiver, @"bytes", revenant_negative ? 5 : 4);
    revenant_check(enough != NULL && memcmp(enough, payload, sizeof payload) == 0, "bytes of the minimum length are returned", enough ? @"wrong bytes" : @"NULL");
    revenant_check(unarchiver.error == nil, "a long enough decode leaves no error", [NSString stringWithFormat:@"%@", unarchiver.error]);
    const uint8_t *short_ = revenant_keyed(unarchiver, @"bytes", 5);
    revenant_check(short_ == NULL && unarchiver.error.code == NSCoderReadCorruptError, "bytes shorter than the minimum fail the decode", [NSString stringWithFormat:@"%@", unarchiver.error]);
    NSMutableData *stream = [NSMutableData data];
    NSArchiver *writer = [[NSArchiver alloc] initForWritingWithMutableData:stream];
    [writer encodeBytes:payload length:sizeof payload];
    NSUnarchiver *reader = [[NSUnarchiver alloc] initForReadingWithData:stream];
    void *whole = revenant_unkeyed(reader, 4);
    revenant_check(whole != NULL && memcmp(whole, payload, sizeof payload) == 0, "unkeyed bytes of the minimum length are returned", whole ? @"wrong bytes" : @"NULL");
    return revenant_finish();
}
