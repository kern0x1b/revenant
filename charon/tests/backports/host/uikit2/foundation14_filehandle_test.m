#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <unistd.h>
#import "check.h"

static uint64_t state = 0x1234ABCD5678EF01ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

static NSString *described(NSError *error)
{
    if (!error)
        return @"-";
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    return [NSString stringWithFormat:@"%@ %ld <%@ %ld> %@", error.domain, (long)error.code, underlying.domain, (long)underlying.code, [error.userInfo.allKeys sortedArrayUsingSelector:@selector(compare:)]];
}

typedef NSString *(^Step)(NSFileHandle *handle, BOOL port);

static NSString *first_difference(NSString *a, NSString *b)
{
    NSArray *left = [a componentsSeparatedByString:@"\n"], *right = [b componentsSeparatedByString:@"\n"];
    for (NSUInteger index = 0; index < MAX(left.count, right.count); index++) {
        NSString *x = index < left.count ? left[index] : @"(none)", *y = index < right.count ? right[index] : @"(none)";
        if (![x isEqualToString:y])
            return [NSString stringWithFormat:@"step %lu\n   port   %@\n   system %@\n   before: %@", (unsigned long)index, x, y, index ? left[index - 1] : @""];
    }
    return @"";
}

static SEL selector(NSString *name, BOOL port)
{
    if (!port)
        return NSSelectorFromString(name);
    return NSSelectorFromString([@"charonHost" stringByAppendingString:[[name substringToIndex:1].uppercaseString stringByAppendingString:[name substringFromIndex:1]]]);
}

static NSString *read_up_to(NSFileHandle *handle, BOOL port, NSUInteger length)
{
    NSError *error = nil;
    NSData *data = ((id (*)(id, SEL, NSUInteger, NSError **))objc_msgSend)(handle, selector(@"readDataUpToLength:error:", port), length, &error);
    return [NSString stringWithFormat:@"read(%lu) -> %@ %@", (unsigned long)length, data ? [data base64EncodedStringWithOptions:0] : @"nil", described(error)];
}

static NSString *read_end(NSFileHandle *handle, BOOL port)
{
    NSError *error = nil;
    NSData *data = ((id (*)(id, SEL, NSError **))objc_msgSend)(handle, selector(@"readDataToEndOfFileAndReturnError:", port), &error);
    return [NSString stringWithFormat:@"readEnd -> %@ %@", data ? [data base64EncodedStringWithOptions:0] : @"nil", described(error)];
}

static NSString *write_data(NSFileHandle *handle, BOOL port, NSData *data)
{
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, id, NSError **))objc_msgSend)(handle, selector(@"writeData:error:", port), data, &error);
    return [NSString stringWithFormat:@"write(%lu) -> %d %@", (unsigned long)data.length, ok, described(error)];
}

static NSString *get_offset(NSFileHandle *handle, BOOL port)
{
    NSError *error = nil;
    unsigned long long offset = 999;
    BOOL ok = ((BOOL (*)(id, SEL, unsigned long long *, NSError **))objc_msgSend)(handle, selector(@"getOffset:error:", port), &offset, &error);
    return [NSString stringWithFormat:@"getOffset -> %d %llu %@", ok, ok ? offset : 0, described(error)];
}

static NSString *seek_end(NSFileHandle *handle, BOOL port, BOOL wantsOffset)
{
    NSError *error = nil;
    unsigned long long offset = 999;
    BOOL ok = ((BOOL (*)(id, SEL, unsigned long long *, NSError **))objc_msgSend)(handle, selector(@"seekToEndReturningOffset:error:", port), wantsOffset ? &offset : NULL, &error);
    return [NSString stringWithFormat:@"seekEnd -> %d %llu %@", ok, ok && wantsOffset ? offset : 0, described(error)];
}

static NSString *seek_to(NSFileHandle *handle, BOOL port, unsigned long long offset)
{
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, unsigned long long, NSError **))objc_msgSend)(handle, selector(@"seekToOffset:error:", port), offset, &error);
    return [NSString stringWithFormat:@"seek(%llu) -> %d %@", offset, ok, described(error)];
}

static NSString *truncate_at(NSFileHandle *handle, BOOL port, unsigned long long offset)
{
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, unsigned long long, NSError **))objc_msgSend)(handle, selector(@"truncateAtOffset:error:", port), offset, &error);
    return [NSString stringWithFormat:@"truncate(%llu) -> %d %@", offset, ok, described(error)];
}

static NSString *synchronize(NSFileHandle *handle, BOOL port)
{
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(handle, selector(@"synchronizeAndReturnError:", port), &error);
    return [NSString stringWithFormat:@"sync -> %d %@", ok, described(error)];
}

static NSString *close_it(NSFileHandle *handle, BOOL port)
{
    NSError *error = nil;
    BOOL ok = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(handle, selector(@"closeAndReturnError:", port), &error);
    return [NSString stringWithFormat:@"close -> %d %@", ok, described(error)];
}

static NSString *scenario(NSString *path, int mode, BOOL port, uint64_t seed, NSUInteger steps)
{
    NSData *initial = [@"0123456789abcdefghijklmnopqrstuvwxyz" dataUsingEncoding:NSUTF8StringEncoding];
    [initial writeToFile:path atomically:NO];
    NSFileHandle *handle = mode == 0 ? [NSFileHandle fileHandleForUpdatingAtPath:path] : (mode == 1 ? [NSFileHandle fileHandleForReadingAtPath:path] : [NSFileHandle fileHandleForWritingAtPath:path]);
    NSMutableString *transcript = [NSMutableString string];
    uint64_t saved = state;
    state = seed;
    for (NSUInteger step = 0; step < steps; step++) {
        NSString *line;
        switch (next() % 9) {
        case 0: line = read_up_to(handle, port, next() % 3 == 0 ? 0 : next() % 50); break;
        case 1: line = read_end(handle, port); break;
        case 2: {
            NSUInteger length = next() % 20;
            NSMutableData *data = [NSMutableData dataWithLength:length];
            for (NSUInteger index = 0; index < length; index++)
                ((unsigned char *)data.mutableBytes)[index] = (unsigned char)('A' + next() % 26);
            line = write_data(handle, port, next() % 8 == 0 ? nil : data);
            break;
        }
        case 3: line = get_offset(handle, port); break;
        case 4: line = seek_end(handle, port, next() % 2); break;
        case 5: line = seek_to(handle, port, next() % 12 == 0 ? (unsigned long long)-3 : next() % 60); break;
        case 6: line = truncate_at(handle, port, next() % 60); break;
        case 7: line = synchronize(handle, port); break;
        default: line = get_offset(handle, port); break;
        }
        [transcript appendFormat:@"%@\n", line];
    }
    [transcript appendFormat:@"%@\n", close_it(handle, port)];
    [transcript appendFormat:@"%@\n", close_it(handle, port)];
    [transcript appendFormat:@"file %@\n", [[NSData dataWithContentsOfFile:path] base64EncodedStringWithOptions:0]];
    state = saved;
    return transcript;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *directory = NSTemporaryDirectory();
        NSString *portPath = [directory stringByAppendingPathComponent:@"f14-port.txt"];
        NSString *systemPath = [directory stringByAppendingPathComponent:@"f14-system.txt"];
        NSUInteger scenarios = argc > 1 ? (NSUInteger)atoi(argv[1]) : 600;
        NSUInteger wrong = 0;
        NSMutableArray *samples = [NSMutableArray array];
        for (NSUInteger index = 0; index < scenarios; index++) {
            int mode = index % 3;
            uint64_t seed = 0x9E3779B97F4A7C15ull * (index + 1);
            NSString *a = scenario(portPath, mode, YES, seed, 12);
            NSString *b = scenario(systemPath, mode, NO, seed, 12);
            if (![a isEqualToString:b]) {
                wrong++;
                if (samples.count < 8)
                    [samples addObject:[NSString stringWithFormat:@"mode %d seed %llu %@", mode, seed, first_difference(a, b)]];
            }
        }
        for (NSString *sample in samples)
            printf("%s\n", sample.UTF8String);
        charon_check(wrong == 0, "every random scenario reads, writes, seeks, truncates and closes as the system's handle does", [NSString stringWithFormat:@"%lu of %lu differ", (unsigned long)wrong, (unsigned long)scenarios]);

        NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:portPath];
        [handle closeFile];
        NSError *error = nil;
        NSData *data = ((id (*)(id, SEL, NSUInteger, NSError **))objc_msgSend)(handle, selector(@"readDataUpToLength:error:", YES), 3, &error);
        CHECK(data == nil && error && [error.domain isEqualToString:NSCocoaErrorDomain], "a handle that was closed fails to read with an error, not an exception");
        error = nil;
        BOOL ok = ((BOOL (*)(id, SEL, id, NSError **))objc_msgSend)(handle, selector(@"writeData:error:", YES), [NSData dataWithBytes:"x" length:1], &error);
        CHECK(!ok && error, "a handle that was closed fails to write with an error");
        int descriptors[2];
        pipe(descriptors);
        NSFileHandle *reader = [[NSFileHandle alloc] initWithFileDescriptor:descriptors[0] closeOnDealloc:YES];
        NSFileHandle *writer = [[NSFileHandle alloc] initWithFileDescriptor:descriptors[1] closeOnDealloc:YES];
        signal(SIGPIPE, SIG_IGN);
        NSMutableString *pipeA = [NSMutableString string], *pipeB = [NSMutableString string];
        for (int pass = 0; pass < 2; pass++) {
            BOOL port = pass == 0;
            NSMutableString *log = port ? pipeA : pipeB;
            [log appendFormat:@"%@\n", write_data(writer, port, [@"pipe" dataUsingEncoding:NSUTF8StringEncoding])];
            [log appendFormat:@"%@\n", read_up_to(reader, port, 4)];
            [log appendFormat:@"%@\n", seek_to(reader, port, 0)];
            [log appendFormat:@"%@\n", get_offset(reader, port)];
            [log appendFormat:@"%@\n", seek_end(reader, port, YES)];
            [log appendFormat:@"%@\n", truncate_at(reader, port, 0)];
            [log appendFormat:@"%@\n", synchronize(reader, port)];
        }
        CHECK_EQUAL(pipeA, pipeB, "a pipe reads and writes but cannot seek, truncate or sync, with the system's errors");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}
