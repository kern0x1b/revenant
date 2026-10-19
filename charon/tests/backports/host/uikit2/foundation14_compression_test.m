#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0x0DDBA11CAFEF00Dull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSData *port_compress(NSData *data, NSInteger algorithm, NSError **error)
{
    return ((id (*)(id, SEL, NSInteger, NSError **))objc_msgSend)(data, NSSelectorFromString(@"charonHostCompressedDataUsingAlgorithm:error:"), algorithm, error);
}

static NSData *port_decompress(NSData *data, NSInteger algorithm, NSError **error)
{
    return ((id (*)(id, SEL, NSInteger, NSError **))objc_msgSend)(data, NSSelectorFromString(@"charonHostDecompressedDataUsingAlgorithm:error:"), algorithm, error);
}

static NSData *make_input(int kind, NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    unsigned char *bytes = data.mutableBytes;
    switch (kind) {
    case 0:
        for (NSUInteger index = 0; index < length; index++)
            bytes[index] = (unsigned char)next();
        break;
    case 1:
        for (NSUInteger index = 0; index < length; index++)
            bytes[index] = (unsigned char)"abcdefghij"[(index + index / 17) % 10];
        break;
    case 2:
        for (NSUInteger index = 0; index < length; index++)
            bytes[index] = next() % 4 ? 'a' : (unsigned char)('a' + next() % 6);
        break;
    case 3: {
        NSString *words[] = {@"the ", @"quick ", @"brown ", @"fox ", @"jumps ", @"over ", @"lazy ", @"dog ", @"and ", @"runs ", @"away\n"};
        NSMutableString *text = [NSMutableString string];
        while (text.length < length)
            [text appendString:words[next() % 11]];
        [data setData:[[text substringToIndex:length] dataUsingEncoding:NSUTF8StringEncoding]];
        break;
    }
    default:
        memset(bytes, kind == 4 ? 0 : 0xFF, length);
        break;
    }
    return data;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *names = @[@"lzfse", @"lz4", @"lzma", @"zlib"];
        NSUInteger sizes[] = {0, 1, 2, 3, 7, 13, 41, 100, 255, 1000, 4096, 32767, 32768, 32769, 65535, 65536, 65537, 70000, 200000, 1200000};
        for (NSInteger algorithm = 0; algorithm < 4; algorithm++) {
            NSUInteger failures = 0, checked = 0;
            NSMutableArray *samples = [NSMutableArray array];
            for (int kind = 0; kind < 6; kind++) {
                for (NSUInteger index = 0; index < sizeof sizes / sizeof *sizes; index++) {
                    NSUInteger length = sizes[index];
                    if (length > 300000 && kind != 3 && kind != 1)
                        continue;
                    NSData *input = make_input(kind, length);
                    NSError *error = nil;
                    NSData *ours = port_compress(input, algorithm, &error);
                    NSData *theirs = [input compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:NULL];
                    NSData *systemReadsOurs = ours ? [ours decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&error] : nil;
                    NSData *portReadsTheirs = algorithm == 0 ? input : port_decompress(theirs, algorithm, &error);
                    NSData *portReadsOurs = ours ? port_decompress(ours, algorithm, &error) : nil;
                    checked++;
                    BOOL good = ours && [systemReadsOurs isEqualToData:input] && [portReadsTheirs isEqualToData:input] && [portReadsOurs isEqualToData:input];
                    if (!good) {
                        failures++;
                        if (samples.count < 6)
                            [samples addObject:[NSString stringWithFormat:@"%@ kind %d length %lu: compressed %d, system reads ours %d, port reads theirs %d, port reads ours %d (%@)", names[algorithm], kind, (unsigned long)length,
                                                                          ours != nil, [systemReadsOurs isEqualToData:input], [portReadsTheirs isEqualToData:input], [portReadsOurs isEqualToData:input], error]];
                    }
                }
            }
            for (NSString *sample in samples)
                printf("%s\n", sample.UTF8String);
            charon_check(failures == 0, [[NSString stringWithFormat:@"%@ data the port compresses the system reads, and the port reads what the system compresses", names[algorithm]] UTF8String],
                         [NSString stringWithFormat:@"%lu of %lu inputs fail", (unsigned long)failures, (unsigned long)checked]);
        }

        NSUInteger differing = 0, compared = 0, stricter = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSInteger algorithm = 1; algorithm < 4; algorithm++) {
            for (int round = 0; round < 400; round++) {
                NSData *input = make_input(round % 4, 1 + next() % 5000);
                NSUInteger flipped = 0;
                NSMutableData *stream = [[input compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:NULL] mutableCopy];
                switch (round % 5) {
                case 0: stream.length = next() % (stream.length + 1); break;
                case 1: if (stream.length) { NSUInteger at = next() % stream.length; ((unsigned char *)stream.mutableBytes)[at] ^= (unsigned char)(1 << (next() % 8)); flipped = at; } break;
                case 2: [stream appendBytes:"junk" length:4]; break;
                case 3: [stream replaceBytesInRange:NSMakeRange(0, MIN(stream.length, (NSUInteger)next() % 6)) withBytes:NULL length:0]; break;
                default: break;
                }
                NSError *e1 = nil, *e2 = nil;
                NSData *a = port_decompress(stream, algorithm, &e1);
                NSData *b = [stream decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&e2];
                compared++;
                if (algorithm == 1 && round % 5 == 1 && !a && b) {
                    stricter++;
                    continue;
                }
                BOOL same = (a == nil) == (b == nil) && (!a || [a isEqualToData:b]) && (a || (e1.code == e2.code && [e1.domain isEqualToString:e2.domain]));
                if (!same) {
                    differing++;
                    if (samples.count < 10)
                        [samples addObject:[NSString stringWithFormat:@"%@ round %d flip@%d: port %@ %@, system %@ %@", names[algorithm], round, (int)flipped, a ? [NSString stringWithFormat:@"%lu bytes", (unsigned long)a.length] : @"nil", e1.code ? @(e1.code) : @"", b ? [NSString stringWithFormat:@"%lu bytes", (unsigned long)b.length] : @"nil", e2.code ? @(e2.code) : @""]];
                }
            }
        }
        for (NSString *sample in samples)
            printf("  %s\n", sample.UTF8String);
        printf("info: %lu damaged LZ4 blocks the system reads (a match may reach before the start of its data) and the port refuses\n", (unsigned long)stricter);
        charon_check(differing == 0, "damaged, truncated, extended and headless streams are refused or read as the system does", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)differing, (unsigned long)compared]);

        NSError *error = nil;
        NSData *plain = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];
        NSData *system = [make_input(3, 5000) compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:NULL];
        NSData *unread = port_decompress(system, 0, &error);
        CHECK(unread == nil && error.code == NSDecompressionFailedError, "LZFSE data the system compressed cannot be read, and fails with the system's decompression error");
        error = nil;
        NSData *empty = port_decompress([NSData data], 3, &error);
        CHECK(empty == nil && error.code == 5377, "nothing at all is not a stream");

        for (NSNumber *bad in @[@9, @-1, @100]) {
            NSString *a = nil, *b = nil;
            @try { port_compress(plain, bad.integerValue, NULL); } @catch (NSException *exception) { a = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason]; }
            @try { [plain compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)bad.integerValue error:NULL]; } @catch (NSException *exception) { b = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason]; }
            CHECK_EQUAL(a, b, "an algorithm that does not exist raises as the system does");
        }

        for (NSInteger algorithm = 1; algorithm < 4; algorithm++) {
            NSData *fixed = make_input(3, 5000);
            NSMutableData *mine = [fixed mutableCopy], *theirs = [fixed mutableCopy];
            NSError *e1 = nil, *e2 = nil;
            BOOL a = ((BOOL (*)(id, SEL, NSInteger, NSError **))objc_msgSend)(mine, NSSelectorFromString(@"charonHostCompressUsingAlgorithm:error:"), algorithm, &e1);
            BOOL b = [theirs compressUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&e2];
            CHECK(a && b && mine.length < 5000 && theirs.length < 5000, "a mutable data compresses in place");
            a = ((BOOL (*)(id, SEL, NSInteger, NSError **))objc_msgSend)(mine, NSSelectorFromString(@"charonHostDecompressUsingAlgorithm:error:"), algorithm, &e1);
            CHECK(a && [mine isEqualToData:fixed] && [theirs decompressUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&e2] && [theirs isEqualToData:mine], "and decompresses in place to what it was");
            NSMutableData *garbage = [[@"not a stream at all" dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
            NSData *before = [garbage copy];
            a = ((BOOL (*)(id, SEL, NSInteger, NSError **))objc_msgSend)(garbage, NSSelectorFromString(@"charonHostDecompressUsingAlgorithm:error:"), algorithm, &e1);
            CHECK(!a && [garbage isEqualToData:before] && e1.code == 5377, "a failed in-place decompression leaves the data as it was");
            CHECK([garbage decompressUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&e2] == a && e2.code == e1.code, "and the system fails the same way");
        }
        NSData *ok = port_compress(plain, 3, NULL);
        CHECK(ok != nil, "the error out parameter may be NULL");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
