#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <unistd.h>
#import "wsserver.h"

/* The answers of iOS 13 and 14 Foundation members, one string per index. The host records them from its own
   Foundation into foundation14-expectations.h; the device computes them with the port and compares. A case that
   needs data the host makes (a compressed stream, an archive) has it in f14_artifacts[] as text. */

#define F14_LISTS 240
#define F14_UNITS 300
#define F14_BYTES 240
#define F14_HEADERS 80
#define F14_HANDLES 90
#define F14_COLLECTIONS 120
#define F14_COOKIES 100
#define F14_STREAMS 24
#define F14_QUEUES 10
#define F14_FLAGS 100
#define F14_SOCKETS 18
#define F14_COUNT (F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES + F14_COLLECTIONS + F14_COOKIES + F14_STREAMS + F14_QUEUES + F14_FLAGS + F14_SOCKETS)

static uint64_t f14_state;

static uint32_t f14_next(void)
{
    f14_state = f14_state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(f14_state >> 33);
}

static NSString *f14_hex(NSData *data)
{
    NSMutableString *hex = [NSMutableString string];
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++)
        [hex appendFormat:@"%02x", bytes[index]];
    return hex;
}

static NSData *f14_unhex(NSString *hex)
{
    NSMutableData *data = [NSMutableData data];
    for (NSUInteger index = 0; index + 1 < hex.length; index += 2) {
        unsigned value;
        sscanf([hex substringWithRange:NSMakeRange(index, 2)].UTF8String, "%02x", &value);
        unsigned char byte = (unsigned char)value;
        [data appendBytes:&byte length:1];
    }
    return data;
}

static NSString *f14_error(NSError *error)
{
    if (!error)
        return @"-";
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    return [NSString stringWithFormat:@"%@ %ld<%@ %ld>", error.domain, (long)error.code, underlying.domain ?: @"-", (long)underlying.code];
}

static NSString *f14_guard(NSString *(^block)(void))
{
    @try {
        return block() ?: @"(nil)";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@", exception.name];
    }
}

static NSString *f14_checksum(NSData *data)
{
    uint32_t sum = 2166136261u;
    const unsigned char *bytes = data.bytes;
    for (NSUInteger index = 0; index < data.length; index++)
        sum = (sum ^ bytes[index]) * 16777619u;
    return [NSString stringWithFormat:@"%lu:%08x", (unsigned long)data.length, sum];
}

static NSString *f14_list_answer(size_t index)
{
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"en_AU", @"de_DE", @"fr_FR", @"es_ES", @"es_MX", @"it_IT", @"pt_BR", @"ja_JP", @"zh_Hans_CN", @"zh_Hant_HK", @"zh_Hant_TW", @"ko_KR", @"ru_RU", @"nl_NL", @"sv_SE", @"pl_PL", @"tr_TR", @"th_TH", @"he_IL", @"ar_SA", @"fa_IR"];
    NSArray *sets = @[@[@"A", @"B"], @[@"A", @"B", @"C"], @[@"A", @"B", @"C", @"D", @"E"], @[@"Ana", @"Isabel"], @[@"Ana", @"hijo", @"hielo"], @[@"אב", @"Ivan"], @[@"กข", @"ฃ", @"z"], @[@"الع", @"one", @"two"], @[@"", @"b"], @[@"one"]];
    NSListFormatter *formatter = [[NSListFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:locales[index / sets.count]];
    NSArray *items = sets[index % sets.count];
    return f14_guard(^{ return [formatter stringFromItems:items]; });
}

static NSString *f14_unit_answer(size_t index)
{
    NSArray *names = @[@"bits", @"nibbles", @"bytes", @"kilobits", @"kilobytes", @"kibibits", @"kibibytes", @"megabits", @"megabytes", @"mebibits", @"mebibytes", @"gigabits", @"gigabytes", @"gibibits", @"gibibytes", @"terabits", @"terabytes", @"tebibits", @"tebibytes", @"petabits", @"petabytes", @"pebibits", @"pebibytes", @"exabits", @"exabytes", @"exbibits", @"exbibytes", @"zettabits", @"zettabytes", @"zebibits", @"zebibytes", @"yottabits", @"yottabytes", @"yobibits", @"yobibytes"];
    f14_state = index * 977 + 3;
    NSString *from = names[f14_next() % names.count], *to = names[f14_next() % names.count];
    double value = ((double)f14_next() / 65536.0) * pow(10.0, (double)(int)(f14_next() % 12) - 3.0) * (f14_next() % 2 ? 1 : -1);
    NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:value unit:[NSUnitInformationStorage performSelector:NSSelectorFromString(from)]];
    NSMeasurement *converted = [measurement measurementByConvertingToUnit:[NSUnitInformationStorage performSelector:NSSelectorFromString(to)]];
    return [NSString stringWithFormat:@"%@ %@ -> %@ %.12g %@", from, to, converted.unit.symbol, converted.doubleValue, [NSUnitInformationStorage performSelector:NSSelectorFromString(from)] == [NSUnitInformationStorage performSelector:NSSelectorFromString(from)] ? @"same" : @"different"];
}

static NSString *f14_byte_answer(size_t index)
{
    NSArray *names = @[@"bits", @"bytes", @"kilobytes", @"kibibytes", @"megabytes", @"mebibytes", @"gigabytes", @"gibibytes", @"terabytes", @"petabytes", @"exabytes", @"zettabytes", @"yottabytes", @"megabits", @"gigabits"];
    f14_state = index * 7919 + 11;
    NSString *unit = names[f14_next() % names.count];
    double value = ((double)f14_next() / 2147483648.0) * pow(10.0, (double)(int)(f14_next() % 9) - 1.0);
    if (f14_next() % 8 == 0)
        value = (double)(f14_next() % 3);
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = (NSByteCountFormatterCountStyle)(f14_next() % 4);
    formatter.includesUnit = f14_next() % 8 != 0;
    formatter.includesCount = f14_next() % 8 != 0;
    formatter.includesActualByteCount = f14_next() % 6 == 0;
    formatter.zeroPadsFractionDigits = f14_next() % 4 == 0;
    formatter.adaptive = f14_next() % 3 != 0;
    if (f14_next() % 4 == 0)
        formatter.allowedUnits = (NSByteCountFormatterUnits)(1u << (f14_next() % 9));
    NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:value unit:[NSUnitInformationStorage performSelector:NSSelectorFromString(unit)]];
    return f14_guard(^{ return [formatter stringFromMeasurement:measurement]; });
}

static NSString *f14_ascii_case(NSString *text, BOOL upper)
{
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger position = 0; position < text.length; position++) {
        unichar c = [text characterAtIndex:position];
        if (upper && c >= 'a' && c <= 'z')
            c -= 32;
        else if (!upper && c >= 'A' && c <= 'Z')
            c += 32;
        [out appendFormat:@"%C", c];
    }
    return out;
}

static NSString *f14_header_answer(size_t index)
{
    NSArray *names = @[@"Content-Type", @"X-Foo", @"Set-Cookie", @"Etag", @"Cache-Control", @"Ünï", @"café", @"straße", @"a", @"x-request-id", @"中文"];
    f14_state = index * 104729 + 5;
    NSMutableDictionary *fields = [NSMutableDictionary dictionary];
    NSUInteger count = f14_next() % 5;
    for (NSUInteger item = 0; item < count; item++) {
        NSString *name = names[f14_next() % names.count];
        NSMutableString *spelled = [NSMutableString string];
        for (NSUInteger position = 0; position < name.length; position++) {
            NSString *c = [name substringWithRange:NSMakeRange(position, 1)];
            [spelled appendString:f14_next() % 3 == 0 ? f14_ascii_case(c, YES) : f14_ascii_case(c, NO)];
        }
        fields[spelled] = [NSString stringWithFormat:@"v%u", f14_next() % 100];
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"http://example.com"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:fields];
    NSMutableString *out = [NSMutableString string];
    for (int probe = 0; probe < 4; probe++) {
        NSString *asked = names[f14_next() % names.count];
        [out appendFormat:@"%@=%@;", asked, [response valueForHTTPHeaderField:f14_ascii_case(asked, YES)] ?: @"-"];
    }
    return out;
}

static NSString *f14_handle_step(NSFileHandle *handle, uint32_t choice, NSMutableString *log)
{
    NSError *error = nil;
    switch (choice % 9) {
    case 0: {
        NSUInteger length = f14_next() % 3 == 0 ? 0 : f14_next() % 50;
        NSData *data = [handle readDataUpToLength:length error:&error];
        return [NSString stringWithFormat:@"read(%lu) -> %@ %@", (unsigned long)length, data ? [data base64EncodedStringWithOptions:0] : @"nil", f14_error(error)];
    }
    case 1: {
        NSData *data = [handle readDataToEndOfFileAndReturnError:&error];
        return [NSString stringWithFormat:@"readEnd -> %@ %@", data ? [data base64EncodedStringWithOptions:0] : @"nil", f14_error(error)];
    }
    case 2: {
        NSUInteger length = f14_next() % 20;
        NSMutableData *data = [NSMutableData dataWithLength:length];
        for (NSUInteger index = 0; index < length; index++)
            ((unsigned char *)data.mutableBytes)[index] = (unsigned char)('A' + f14_next() % 26);
        BOOL empty = f14_next() % 8 == 0;
        BOOL ok = [handle writeData:empty ? nil : data error:&error];
        return [NSString stringWithFormat:@"write(%lu) -> %d %@", (unsigned long)(empty ? 0 : length), ok, f14_error(error)];
    }
    case 3:
    default: {
        unsigned long long offset = 999;
        BOOL ok = [handle getOffset:&offset error:&error];
        return [NSString stringWithFormat:@"getOffset -> %d %llu %@", ok, ok ? offset : 0, f14_error(error)];
    }
    case 4: {
        unsigned long long offset = 999;
        BOOL wants = f14_next() % 2;
        BOOL ok = [handle seekToEndReturningOffset:wants ? &offset : NULL error:&error];
        return [NSString stringWithFormat:@"seekEnd -> %d %llu %@", ok, ok && wants ? offset : 0, f14_error(error)];
    }
    case 5: {
        unsigned long long offset = f14_next() % 12 == 0 ? (unsigned long long)-3 : f14_next() % 60;
        BOOL ok = [handle seekToOffset:offset error:&error];
        return [NSString stringWithFormat:@"seek(%llu) -> %d %@", offset, ok, f14_error(error)];
    }
    case 6: {
        unsigned long long offset = f14_next() % 60;
        BOOL ok = [handle truncateAtOffset:offset error:&error];
        return [NSString stringWithFormat:@"truncate(%llu) -> %d %@", offset, ok, f14_error(error)];
    }
    case 7: {
        BOOL ok = [handle synchronizeAndReturnError:&error];
        return [NSString stringWithFormat:@"sync -> %d %@", ok, f14_error(error)];
    }
    }
}

static NSString *f14_handle_answer(size_t index)
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"f14-handle.txt"];
    [[@"0123456789abcdefghijklmnopqrstuvwxyz" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:NO];
    int mode = index % 3;
    NSFileHandle *handle = mode == 0 ? [NSFileHandle fileHandleForUpdatingAtPath:path] : (mode == 1 ? [NSFileHandle fileHandleForReadingAtPath:path] : [NSFileHandle fileHandleForWritingAtPath:path]);
    NSMutableString *transcript = [NSMutableString string];
    f14_state = 0x9E3779B97F4A7C15ull * (index + 1);
    for (int step = 0; step < 12; step++) {
        uint32_t choice = f14_next();
        [transcript appendFormat:@"%@\n", f14_handle_step(handle, choice, transcript)];
    }
    NSError *error = nil;
    [transcript appendFormat:@"close -> %d\n", [handle closeAndReturnError:&error]];
    [transcript appendFormat:@"close -> %d\n", [handle closeAndReturnError:&error]];
    [transcript appendFormat:@"file %@", [[NSData dataWithContentsOfFile:path] base64EncodedStringWithOptions:0]];
    return transcript;
}

static NSData *f14_archive(id root, BOOL keyed, BOOL secure)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    archiver.outputFormat = NSPropertyListBinaryFormat_v1_0;
    [archiver setRequiresSecureCoding:secure];
    [archiver encodeObject:root forKey:keyed ? @"k" : NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    return data;
}

static id f14_random_leaf(void)
{
    switch (f14_next() % 8) {
    case 0: return @(f14_next() % 100);
    case 1: return [NSNull null];
    case 2: return [NSDate dateWithTimeIntervalSince1970:f14_next() % 1000];
    case 3: return [NSData dataWithBytes:"ab" length:2];
    case 4: return [NSURL URLWithString:@"http://example.com"];
    case 5: return [[NSUUID alloc] initWithUUIDString:@"E621E1F8-C36C-495A-93FC-0C247A3E6E5F"];
    default: return [NSString stringWithFormat:@"s%u", f14_next() % 50];
    }
}

static Class f14_first(NSSet *classes)
{
    return [[classes.allObjects sortedArrayUsingComparator:^NSComparisonResult(Class a, Class b) { return [NSStringFromClass(a) compare:NSStringFromClass(b)]; }] firstObject];
}

static NSSet *f14_random_classes(void)
{
    NSArray *all = @[[NSString class], [NSNumber class], [NSDate class], [NSData class], [NSNull class], [NSURL class], [NSUUID class], [NSArray class], [NSDictionary class], [NSSet class], [NSObject class]];
    NSMutableSet *set = [NSMutableSet set];
    NSUInteger count = 1 + f14_next() % 3;
    for (NSUInteger index = 0; index < count; index++)
        [set addObject:all[f14_next() % (f14_next() % 3 ? 7 : all.count)]];
    return set;
}

static NSString *f14_collection_artifact(size_t index)
{
    f14_state = index * 31337 + 7;
    BOOL dictionary = f14_next() % 3 == 0;
    id root;
    if (dictionary) {
        root = [NSMutableDictionary dictionary];
        for (NSUInteger item = 0; item < 1 + f14_next() % 3; item++)
            root[f14_next() % 6 == 0 ? @(f14_next() % 5) : [NSString stringWithFormat:@"k%u", f14_next() % 9]] = f14_next() % 8 == 0 ? @[@"x"] : f14_random_leaf();
    } else {
        root = [NSMutableArray array];
        for (NSUInteger item = 0; item < f14_next() % 5; item++)
            [root addObject:f14_next() % 7 == 0 ? @[f14_random_leaf()] : f14_random_leaf()];
    }
    return f14_hex(f14_archive(root, index % 2, YES));
}

static NSString *f14_kind(id object)
{
    if ([object isKindOfClass:[NSString class]])
        return @"S";
    if ([object isKindOfClass:[NSNumber class]])
        return @"N";
    if ([object isKindOfClass:[NSDate class]])
        return @"D";
    if ([object isKindOfClass:[NSData class]])
        return @"X";
    if ([object isKindOfClass:[NSNull class]])
        return @"L";
    if ([object isKindOfClass:[NSURL class]])
        return @"U";
    if ([object isKindOfClass:[NSUUID class]])
        return @"I";
    return @"?";
}

static NSString *f14_kinds(id value)
{
    NSMutableArray *kinds = [NSMutableArray array];
    for (id member in [value isKindOfClass:[NSDictionary class]] ? [[value allKeys] arrayByAddingObjectsFromArray:[value allValues]] : value)
        [kinds addObject:f14_kind(member)];
    return [[kinds sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@""];
}

static NSString *f14_collection_answer(size_t index, NSString *artifact)
{
    f14_state = index * 31337 + 7;
    BOOL dictionary = f14_next() % 3 == 0;
    NSData *data = f14_unhex(artifact);
    f14_state = index * 4243 + 99;
    NSSet *keyClasses = f14_random_classes(), *valueClasses = f14_random_classes();
    BOOL classForm = f14_next() % 2, classMethod = index % 2 == 0;
    NSInteger policy = f14_next() % 2;
    if (classForm) {
        keyClasses = [NSSet setWithObject:f14_first(keyClasses)];
        valueClasses = [NSSet setWithObject:f14_first(valueClasses)];
    }
    return f14_guard(^{
        NSError *error = nil;
        id value = nil;
        if (classMethod) {
            if (dictionary)
                value = classForm ? [NSKeyedUnarchiver unarchivedDictionaryWithKeysOfClass:f14_first(keyClasses) objectsOfClass:f14_first(valueClasses) fromData:data error:&error] : [NSKeyedUnarchiver unarchivedDictionaryWithKeysOfClasses:keyClasses objectsOfClasses:valueClasses fromData:data error:&error];
            else
                value = classForm ? [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:f14_first(keyClasses) fromData:data error:&error] : [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClasses:keyClasses fromData:data error:&error];
        } else {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
            unarchiver.requiresSecureCoding = YES;
            unarchiver.decodingFailurePolicy = (NSDecodingFailurePolicy)policy;
            if (dictionary)
                value = classForm ? [unarchiver decodeDictionaryWithKeysOfClass:f14_first(keyClasses) objectsOfClass:f14_first(valueClasses) forKey:@"k"] : [unarchiver decodeDictionaryWithKeysOfClasses:keyClasses objectsOfClasses:valueClasses forKey:@"k"];
            else
                value = classForm ? [unarchiver decodeArrayOfObjectsOfClass:f14_first(keyClasses) forKey:@"k"] : [unarchiver decodeArrayOfObjectsOfClasses:keyClasses forKey:@"k"];
            error = unarchiver.error;
        }
        NSString *kinds = value ? [NSString stringWithFormat:@"%lu:%@", (unsigned long)[value count], f14_kinds(value)] : @"nil";
        return [NSString stringWithFormat:@"%@ | %@ %ld", kinds, error.domain ?: @"-", (long)error.code];
    });
}

static NSString *f14_cookie_answer(size_t index)
{
    f14_state = index * 65537 + 13;
    NSArray *values = @[@"Lax", @"lax", @"STRICT", @"Strict", @"None", @"none", @"bogus", @"", @" lax", @"laxx"];
    NSURL *URL = [NSURL URLWithString:@"http://x.com/"];
    if (index % 2 == 0) {
        NSMutableDictionary *properties = [@{NSHTTPCookieName: @"n", NSHTTPCookieValue: @"v", NSHTTPCookieDomain: @"x.com", NSHTTPCookiePath: @"/"} mutableCopy];
        if (f14_next() % 5)
            properties[@"SameSite"] = values[f14_next() % values.count];
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:properties];
        return [NSString stringWithFormat:@"%@ %@ %@", cookie ? @"cookie" : @"nil", cookie.sameSitePolicy ?: @"-", cookie.properties[@"SameSite"] ?: @"-"];
    }
    NSMutableArray *parts = [NSMutableArray array];
    for (NSUInteger part = 0; part < 1 + f14_next() % 3; part++) {
        NSMutableString *cookie = [NSMutableString stringWithFormat:@"c%lu=v%u", (unsigned long)part, f14_next() % 9];
        NSString *spelling = @[@"SameSite", @"samesite", @"SAMESITE"][f14_next() % 3];
        for (NSUInteger attribute = 0; attribute < f14_next() % 4; attribute++) {
            switch (f14_next() % 5) {
            case 0: [cookie appendFormat:@"; %@=%@", spelling, values[f14_next() % values.count]]; break;
            case 1: [cookie appendString:@"; Max-Age=3600"]; break;
            case 2: [cookie appendString:@"; Path=/"]; break;
            case 3: [cookie appendString:@"; HttpOnly"]; break;
            default: [cookie appendString:@"; Secure"]; break;
            }
        }
        [parts addObject:cookie];
    }
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:@{@"Set-Cookie": [parts componentsJoinedByString:@", "]} forURL:URL];
    NSMutableString *out = [NSMutableString string];
    for (NSHTTPCookie *cookie in cookies)
        [out appendFormat:@"[%@=%@ %@]", cookie.name, cookie.value, cookie.sameSitePolicy ?: @"-"];
    return out;
}

static NSString *f14_stream_artifact(size_t index)
{
    NSUInteger sizes[] = {0, 1, 41, 300, 5000, 70000, 200000, 33000};
    NSInteger algorithm = 1 + index % 3;
    NSUInteger length = sizes[index / 3];
    NSMutableData *input = [NSMutableData dataWithLength:length];
    unsigned char *bytes = input.mutableBytes;
    for (NSUInteger position = 0; position < length; position++)
        bytes[position] = (unsigned char)"the quick brown fox jumps over the lazy dog "[(position + position / 91) % 45];
    return f14_hex([input compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:NULL]);
}

static NSString *f14_stream_answer(size_t index, NSString *artifact)
{
    NSUInteger sizes[] = {0, 1, 41, 300, 5000, 70000, 200000, 33000};
    NSInteger algorithm = 1 + index % 3;
    NSUInteger length = sizes[index / 3];
    NSMutableData *expected = [NSMutableData dataWithLength:length];
    unsigned char *bytes = expected.mutableBytes;
    for (NSUInteger position = 0; position < length; position++)
        bytes[position] = (unsigned char)"the quick brown fox jumps over the lazy dog "[(position + position / 91) % 45];
    NSError *error = nil;
    NSData *plain = [f14_unhex(artifact) decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:&error];
    NSData *again = [[expected compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:NULL] decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)algorithm error:NULL];
    return [NSString stringWithFormat:@"%@ %@ roundtrip=%d", plain ? f14_checksum(plain) : @"nil", f14_error(error), [again isEqualToData:expected]];
}

static NSMutableArray *f14_events;
static NSLock *f14_lock;

static void f14_note(NSString *text)
{
    [f14_lock lock];
    [f14_events addObject:text];
    [f14_lock unlock];
}

static NSString *f14_drain(NSTimeInterval wait)
{
    [NSThread sleepForTimeInterval:wait];
    [f14_lock lock];
    NSString *joined = [f14_events componentsJoinedByString:@","];
    [f14_events removeAllObjects];
    [f14_lock unlock];
    return joined;
}

static NSString *f14_queue_answer(size_t which)
{
    if (!f14_events) {
        f14_events = [NSMutableArray array];
        f14_lock = [[NSLock alloc] init];
    }
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [f14_events removeAllObjects];
    switch (which) {
    case 0: {
        queue.maxConcurrentOperationCount = 4;
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.1]; f14_note(@"a"); }];
        [queue addBarrierBlock:^{ f14_note(@"|"); [NSThread sleepForTimeInterval:0.1]; f14_note(@"|"); }];
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{ f14_note(@"b"); }];
        return f14_drain(1.5);
    }
    case 1: {
        queue.suspended = YES;
        [queue addOperationWithBlock:^{ f14_note(@"op1"); }];
        [queue addBarrierBlock:^{ f14_note(@"bar"); }];
        [queue addOperationWithBlock:^{ f14_note(@"op3"); }];
        [NSThread sleepForTimeInterval:0.3];
        f14_note(@"resume");
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        f14_note(@"waited");
        return f14_drain(0.5);
    }
    case 2: {
        queue.suspended = YES;
        [queue addBarrierBlock:^{ f14_note(@"bar"); }];
        [queue addOperationWithBlock:^{ f14_note(@"op"); }];
        [NSThread sleepForTimeInterval:0.4];
        f14_note(@"resume");
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        f14_note(@"waited");
        return f14_drain(0.5);
    }
    case 3: {
        queue.suspended = YES;
        [queue addOperationWithBlock:^{ f14_note(@"op1"); }];
        [queue addBarrierBlock:^{ f14_note(@"bar"); }];
        [queue addOperationWithBlock:^{ f14_note(@"op3"); }];
        f14_note([NSString stringWithFormat:@"count=%lu", (unsigned long)queue.operationCount]);
        [queue cancelAllOperations];
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        return f14_drain(0.6);
    }
    case 4: {
        queue.maxConcurrentOperationCount = 1;
        [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.1]; f14_note(@"x"); }];
        [queue addBarrierBlock:^{ f14_note(@"bar"); }];
        [queue addOperations:@[[NSBlockOperation blockOperationWithBlock:^{ f14_note(@"w"); }]] waitUntilFinished:YES];
        return f14_drain(0.4);
    }
    case 5: {
        __block NSString *thread = @"?";
        [queue addBarrierBlock:^{ thread = [NSThread isMainThread] ? @"main" : @"other"; f14_note([NSString stringWithFormat:@"queue=%d", [NSOperationQueue currentQueue] == queue]); }];
        [NSThread sleepForTimeInterval:0.4];
        f14_note(thread);
        return f14_drain(0.2);
    }
    case 6: {
        queue.maxConcurrentOperationCount = 4;
        for (int index = 0; index < 2; index++)
            [queue addOperationWithBlock:^{ [NSThread sleepForTimeInterval:0.1]; f14_note(@"p"); }];
        [queue addBarrierBlock:^{ f14_note(@"B1"); }];
        [queue addBarrierBlock:^{ f14_note(@"B2"); }];
        [queue addOperationWithBlock:^{ f14_note(@"q"); }];
        return f14_drain(1.0);
    }
    case 7: {
        NSProgress *p = queue.progress;
        f14_note([NSString stringWithFormat:@"same=%d total=%lld done=%lld", p == queue.progress, p.totalUnitCount, p.completedUnitCount]);
        queue.suspended = YES;
        for (int index = 0; index < 3; index++)
            [queue addOperationWithBlock:^{}];
        p.totalUnitCount = 10;
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.4];
        f14_note([NSString stringWithFormat:@"total=%lld done=%lld", p.totalUnitCount, p.completedUnitCount]);
        NSOperation *cancelled = [NSBlockOperation blockOperationWithBlock:^{}];
        queue.suspended = YES;
        [queue addOperation:cancelled];
        [cancelled cancel];
        [queue addOperationWithBlock:^{}];
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.4];
        f14_note([NSString stringWithFormat:@"after cancelled done=%lld", p.completedUnitCount]);
        return f14_drain(0.2);
    }
    case 8: {
        [queue addOperationWithBlock:^{}];
        [queue addOperationWithBlock:^{}];
        [queue waitUntilAllOperationsAreFinished];
        NSProgress *p = queue.progress;
        p.totalUnitCount = 5;
        [queue addOperationWithBlock:^{}];
        [queue waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.4];
        f14_note([NSString stringWithFormat:@"late progress done=%lld", p.completedUnitCount]);
        NSOperationQueue *other = [[NSOperationQueue alloc] init];
        NSProgress *q = other.progress;
        [other addOperationWithBlock:^{}];
        [other waitUntilAllOperationsAreFinished];
        [NSThread sleepForTimeInterval:0.3];
        f14_note([NSString stringWithFormat:@"no total done=%lld", q.completedUnitCount]);
        return f14_drain(0.2);
    }
    default: {
        queue.suspended = YES;
        NSBlockOperation *first = [NSBlockOperation blockOperationWithBlock:^{ f14_note(@"first"); }];
        [queue addOperation:first];
        [queue addBarrierBlock:^{ f14_note(@"bar"); }];
        [queue addOperationWithBlock:^{ f14_note(@"after"); }];
        f14_note([NSString stringWithFormat:@"deps=%lu ops=%lu", (unsigned long)first.dependencies.count, (unsigned long)queue.operations.count]);
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        return f14_drain(0.6);
    }
    }
}

static NSString *f14_flag_answer(size_t index)
{
    f14_state = index * 40503 + 17;
    NSURL *URL = [NSURL URLWithString:@"http://example.com/"];
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:URL];
    NSURLRequest *current = mutableRequest;
    NSMutableString *log = [NSMutableString stringWithFormat:@"%d%d", current.allowsExpensiveNetworkAccess, current.allowsConstrainedNetworkAccess];
    for (int step = 0; step < 6; step++) {
        switch (f14_next() % 6) {
        case 0: mutableRequest.allowsExpensiveNetworkAccess = f14_next() % 2; break;
        case 1: mutableRequest.allowsConstrainedNetworkAccess = f14_next() % 2; break;
        case 2: current = [mutableRequest copy]; break;
        case 3: mutableRequest = [current mutableCopy]; current = mutableRequest; break;
        case 4: current = [[NSURLRequest alloc] initWithURL:URL]; break;
        default: current = [mutableRequest mutableCopy]; mutableRequest = (NSMutableURLRequest *)current; break;
        }
        [log appendFormat:@" %d%d|%d%d", current.allowsExpensiveNetworkAccess, current.allowsConstrainedNetworkAccess, mutableRequest.allowsExpensiveNetworkAccess, mutableRequest.allowsConstrainedNetworkAccess];
    }
    return log;
}

@interface F14Watcher : NSObject <NSURLSessionWebSocketDelegate, NSURLSessionTaskDelegate>
@property (strong) NSMutableArray *events;
@end

@implementation F14Watcher
- (instancetype)init
{
    self = [super init];
    _events = [NSMutableArray array];
    return self;
}
- (void)add:(NSString *)text
{
    @synchronized (self) {
        [_events addObject:text];
    }
}
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)task didOpenWithProtocol:(NSString *)protocol
{
    [self add:[NSString stringWithFormat:@"open %@", protocol ?: @"-"]];
}
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)task didCloseWithCode:(NSURLSessionWebSocketCloseCode)code reason:(NSData *)reason
{
    [self add:[NSString stringWithFormat:@"close %ld %@", (long)code, reason ? [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] : @"-"]];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    [self add:[NSString stringWithFormat:@"complete %@ state=%ld", error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"-", (long)task.state]];
}
@end

static void f14_spin(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

static NSString *f14_message_text(NSURLSessionWebSocketMessage *message)
{
    if (!message)
        return @"nil";
    return message.type == NSURLSessionWebSocketMessageTypeString ? [NSString stringWithFormat:@"string(%lu):%@", (unsigned long)message.string.length, [message.string substringToIndex:MIN((NSUInteger)20, message.string.length)]] : [NSString stringWithFormat:@"data(%lu)", (unsigned long)message.data.length];
}

static NSString *f14_short(NSError *error)
{
    return error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code] : @"-";
}

static NSString *f14_server_lines(void)
{
    NSMutableArray *kept = [NSMutableArray array];
    for (NSString *line in wsserver_lines()) {
        if ([line hasPrefix:@"header-names"] || [line hasPrefix:@"header host"] || [line hasPrefix:@"header origin"])
            continue;
        [kept addObject:line];
    }
    return [kept componentsJoinedByString:@" | "];
}

static int f14_listener;

static NSString *f14_socket_answer(int which)
{
    if (!f14_listener)
        f14_listener = wsserver_start();
    NSURL *(^url)(NSString *) = ^NSURL *(NSString *path) {
        return [NSURL URLWithString:[NSString stringWithFormat:@"ws://127.0.0.1:%d%@", f14_listener, path]];
    };
    F14Watcher *watcher = [[F14Watcher alloc] init];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:watcher delegateQueue:queue];
    NSMutableArray *log = [NSMutableArray array];
    void (^L)(NSString *) = ^(NSString *text) {
        @synchronized (log) {
            [log addObject:text];
        }
    };
    wsserver_reset();
    NSURLSessionWebSocketTask *task = nil;
    const NSTimeInterval scale = 1.6;
    switch (which) {
    case 0: {
        task = [session webSocketTaskWithURL:url(@"/echo")];
        [task resume];
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:@"hello"] completionHandler:^(NSError *e) { L([NSString stringWithFormat:@"send1 %@", f14_short(e)]); }];
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:[NSData dataWithBytes:"\x01\x02\x03" length:3]] completionHandler:^(NSError *e) { L([NSString stringWithFormat:@"send2 %@", f14_short(e)]); }];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv1 %@ %@ queue=%d", f14_message_text(m), f14_short(e), [NSOperationQueue currentQueue] == queue]); }];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv2 %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task sendPingWithPongReceiveHandler:^(NSError *e) { L([NSString stringWithFormat:@"pong %@", f14_short(e)]); }];
        f14_spin(0.5 * scale);
        L([NSString stringWithFormat:@"response %ld", (long)[(NSHTTPURLResponse *)task.response statusCode]]);
        L([NSString stringWithFormat:@"before close: state=%ld closeCode=%ld", (long)task.state, (long)task.closeCode]);
        [task cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:[@"done" dataUsingEncoding:NSUTF8StringEncoding]];
        f14_spin(0.5 * scale);
        L([NSString stringWithFormat:@"after close: state=%ld closeCode=%ld reason=%@ error=%@", (long)task.state, (long)task.closeCode, [[NSString alloc] initWithData:task.closeReason ?: [NSData data] encoding:NSUTF8StringEncoding], f14_short(task.error)]);
        break;
    }
    case 1: {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url(@"/proto")];
        [request setValue:@"abc" forHTTPHeaderField:@"X-Custom"];
        task = [session webSocketTaskWithRequest:request];
        [task resume];
        f14_spin(0.4 * scale);
        [task cancel];
        f14_spin(0.3 * scale);
        L([NSString stringWithFormat:@"cancelled: state=%ld error=%@ closeCode=%ld", (long)task.state, f14_short(task.error), (long)task.closeCode]);
        NSURLSessionWebSocketTask *second = [session webSocketTaskWithURL:url(@"/proto") protocols:@[@"chat", @"superchat"]];
        [second resume];
        f14_spin(0.4 * scale);
        [second cancelWithCloseCode:NSURLSessionWebSocketCloseCodeGoingAway reason:nil];
        f14_spin(0.4 * scale);
        L([NSString stringWithFormat:@"second: state=%ld closeCode=%ld", (long)second.state, (long)second.closeCode]);
        break;
    }
    case 2:
    case 3:
    case 4: {
        task = [session webSocketTaskWithURL:url(which == 2 ? @"/reject" : (which == 3 ? @"/plain" : @"/badaccept"))];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:@"x"] completionHandler:^(NSError *e) { L([NSString stringWithFormat:@"send %@", f14_short(e)]); }];
        [task resume];
        f14_spin(0.6 * scale);
        L([NSString stringWithFormat:@"state=%ld error=%@ status=%ld", (long)task.state, f14_short(task.error), (long)[(NSHTTPURLResponse *)task.response statusCode]]);
        break;
    }
    case 5: {
        task = [session webSocketTaskWithURL:[NSURL URLWithString:@"ws://127.0.0.1:1/x"]];
        [task resume];
        f14_spin(0.8 * scale);
        L([NSString stringWithFormat:@"state=%ld error=%@ failing=%@", (long)task.state, f14_short(task.error), task.error.userInfo[NSURLErrorFailingURLStringErrorKey]]);
        break;
    }
    case 6: {
        task = [session webSocketTaskWithURL:url(@"/closenow")];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task resume];
        f14_spin(0.6 * scale);
        L([NSString stringWithFormat:@"state=%ld closeCode=%ld reason=%@ error=%@", (long)task.state, (long)task.closeCode, [[NSString alloc] initWithData:task.closeReason ?: [NSData data] encoding:NSUTF8StringEncoding], f14_short(task.error)]);
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"late recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:@"x"] completionHandler:^(NSError *e) { L([NSString stringWithFormat:@"late send %@", f14_short(e)]); }];
        [task sendPingWithPongReceiveHandler:^(NSError *e) { L([NSString stringWithFormat:@"late ping %@", f14_short(e)]); }];
        f14_spin(0.4 * scale);
        break;
    }
    case 7: {
        task = [session webSocketTaskWithURL:url(@"/frag")];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task resume];
        f14_spin(0.5 * scale);
        [task cancel];
        f14_spin(0.3 * scale);
        break;
    }
    case 8:
    case 9:
    case 10: {
        task = [session webSocketTaskWithURL:url(which == 10 ? @"/badutf8" : @"/big")];
        if (which == 9)
            task.maximumMessageSize = 3000000;
        L([NSString stringWithFormat:@"max=%ld", (long)task.maximumMessageSize]);
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task resume];
        f14_spin(1.5 * scale);
        L([NSString stringWithFormat:@"state=%ld error=%@ closeCode=%ld", (long)task.state, f14_short(task.error), (long)task.closeCode]);
        [task cancel];
        f14_spin(0.3 * scale);
        break;
    }
    case 11: {
        task = [session webSocketTaskWithURL:url(@"/ping")];
        [task resume];
        f14_spin(0.5 * scale);
        [task cancel];
        f14_spin(0.3 * scale);
        break;
    }
    case 12: {
        task = [session webSocketTaskWithURL:url(@"/abort")];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [task sendPingWithPongReceiveHandler:^(NSError *e) { L([NSString stringWithFormat:@"pong %@", f14_short(e)]); }];
        [task resume];
        f14_spin(0.8 * scale);
        L([NSString stringWithFormat:@"state=%ld error=%@", (long)task.state, f14_short(task.error)]);
        break;
    }
    case 13: {
        task = [session webSocketTaskWithURL:url(@"/echo")];
        [task resume];
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:@"__close__"] completionHandler:^(NSError *e) {}];
        [task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        f14_spin(0.6 * scale);
        L([NSString stringWithFormat:@"state=%ld closeCode=%ld reason=%@ error=%@", (long)task.state, (long)task.closeCode, [[NSString alloc] initWithData:task.closeReason ?: [NSData data] encoding:NSUTF8StringEncoding], f14_short(task.error)]);
        break;
    }
    case 14: {
        task = [session webSocketTaskWithURL:url(@"/echo")];
        [task cancel];
        f14_spin(0.3 * scale);
        L([NSString stringWithFormat:@"cancelled before resume: state=%ld error=%@", (long)task.state, f14_short(task.error)]);
        NSURLSessionWebSocketTask *live = [session webSocketTaskWithURL:url(@"/echo")];
        [live resume];
        [live receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"pending recv %@ %@", f14_message_text(m), f14_short(e)]); }];
        [live sendPingWithPongReceiveHandler:^(NSError *e) { L([NSString stringWithFormat:@"pending ping %@", f14_short(e)]); }];
        f14_spin(0.3 * scale);
        [live cancelWithCloseCode:NSURLSessionWebSocketCloseCodeGoingAway reason:nil];
        f14_spin(0.5 * scale);
        [live receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *m, NSError *e) { L([NSString stringWithFormat:@"recv after %@ %@", f14_message_text(m), f14_short(e)]); }];
        [live sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:@"z"] completionHandler:^(NSError *e) { L([NSString stringWithFormat:@"send after %@", f14_short(e)]); }];
        f14_spin(0.3 * scale);
        L([NSString stringWithFormat:@"live state=%ld closeCode=%ld", (long)live.state, (long)live.closeCode]);
        NSURLSessionWebSocketTask *zero = [session webSocketTaskWithURL:url(@"/echo")];
        [zero resume];
        f14_spin(0.3 * scale);
        [zero cancelWithCloseCode:NSURLSessionWebSocketCloseCodeInvalid reason:nil];
        f14_spin(0.4 * scale);
        L([NSString stringWithFormat:@"code 0: state=%ld error=%@", (long)zero.state, f14_short(zero.error)]);
        break;
    }
    case 15: {
        task = [session webSocketTaskWithURL:url(@"/cookie")];
        [task resume];
        f14_spin(0.5 * scale);
        L([NSString stringWithFormat:@"stored %@", [[configuration.HTTPCookieStorage cookies] valueForKey:@"name"]]);
        [task cancel];
        f14_spin(0.2 * scale);
        [configuration.HTTPCookieStorage setCookie:[NSHTTPCookie cookieWithProperties:@{NSHTTPCookieName: @"pre", NSHTTPCookieValue: @"1", NSHTTPCookieDomain: @"127.0.0.1", NSHTTPCookiePath: @"/"}]];
        wsserver_reset();
        NSURLSessionWebSocketTask *again = [session webSocketTaskWithURL:url(@"/echo")];
        [again resume];
        f14_spin(0.4 * scale);
        [again cancel];
        f14_spin(0.2 * scale);
        break;
    }
    case 16: {
        NSURLSession *other = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration] delegate:watcher delegateQueue:queue];
        task = [other webSocketTaskWithURL:url(@"/echo")];
        [task resume];
        f14_spin(0.3 * scale);
        [other invalidateAndCancel];
        f14_spin(0.5 * scale);
        L([NSString stringWithFormat:@"state=%ld error=%@", (long)task.state, f14_short(task.error)]);
        NSString *raised = @"nothing";
        @try {
            [other webSocketTaskWithURL:url(@"/echo")];
        } @catch (NSException *exception) {
            raised = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
        }
        L([NSString stringWithFormat:@"new task: %@", raised]);
        break;
    }
    default: {
        for (NSString *scheme in @[@"http://127.0.0.1:1/x", @"ftp://127.0.0.1:1/x"]) {
            NSString *raised = @"nothing";
            @try {
                [session webSocketTaskWithURL:[NSURL URLWithString:scheme]];
            } @catch (NSException *exception) {
                raised = [NSString stringWithFormat:@"%@ %@", exception.name, exception.reason];
            }
            L([NSString stringWithFormat:@"%@: %@", scheme, raised]);
        }
        NSURLSessionWebSocketMessage *text = [[NSURLSessionWebSocketMessage alloc] initWithString:@"abc"], *data = [[NSURLSessionWebSocketMessage alloc] initWithData:[NSData dataWithBytes:"ab" length:2]];
        L([NSString stringWithFormat:@"text type=%ld string=%@ data=%@ desc=%@", (long)text.type, text.string, text.data ? f14_hex(text.data) : nil, text]);
        L([NSString stringWithFormat:@"data type=%ld string=%@ data=%@", (long)data.type, data.string, data.data ? f14_hex(data.data) : nil]);
        task = [session webSocketTaskWithURL:url(@"/echo")];
        L([NSString stringWithFormat:@"new: state=%ld max=%ld closeCode=%ld reason=%@ response=%@ error=%@ request=%@", (long)task.state, (long)task.maximumMessageSize, (long)task.closeCode, task.closeReason, task.response, f14_short(task.error), task.originalRequest.URL.scheme]);
        [task cancel];
        f14_spin(0.3 * scale);
        break;
    }
    }
    NSString *transcript;
    @synchronized (log) {
        if (which == 6) {
            NSMutableArray *late = [NSMutableArray array];
            for (NSString *line in [log copy]) {
                if ([line hasPrefix:@"late"])
                    [late addObject:line];
            }
            [log removeObjectsInArray:late];
            [log addObjectsFromArray:[late sortedArrayUsingSelector:@selector(compare:)]];
        }
        transcript = [NSString stringWithFormat:@"%@\n   events: %@\n   server: %@", [log componentsJoinedByString:@"\n   "], [watcher.events componentsJoinedByString:@" ; "], f14_server_lines()];
    }
    [session invalidateAndCancel];
    return transcript;
}

static NSString *f14_artifact(size_t index)
{
    size_t base = F14_LISTS + F14_UNITS + F14_BYTES + F14_HEADERS + F14_HANDLES;
    if (index >= base && index < base + F14_COLLECTIONS)
        return f14_collection_artifact(index - base);
    base += F14_COLLECTIONS + F14_COOKIES;
    if (index >= base && index < base + F14_STREAMS)
        return f14_stream_artifact(index - base);
    return @"";
}

static NSString *f14_answer(size_t index, NSString *artifact)
{
    if (index < F14_LISTS)
        return f14_list_answer(index);
    index -= F14_LISTS;
    if (index < F14_UNITS)
        return f14_unit_answer(index);
    index -= F14_UNITS;
    if (index < F14_BYTES)
        return f14_byte_answer(index);
    index -= F14_BYTES;
    if (index < F14_HEADERS)
        return f14_header_answer(index);
    index -= F14_HEADERS;
    if (index < F14_HANDLES)
        return f14_handle_answer(index);
    index -= F14_HANDLES;
    if (index < F14_COLLECTIONS)
        return f14_collection_answer(index, artifact);
    index -= F14_COLLECTIONS;
    if (index < F14_COOKIES)
        return f14_cookie_answer(index);
    index -= F14_COOKIES;
    if (index < F14_STREAMS)
        return f14_stream_answer(index, artifact);
    index -= F14_STREAMS;
    if (index < F14_QUEUES)
        return f14_queue_answer(index);
    index -= F14_QUEUES;
    if (index < F14_FLAGS)
        return f14_flag_answer(index);
    index -= F14_FLAGS;
    return f14_socket_answer((int)index);
}
